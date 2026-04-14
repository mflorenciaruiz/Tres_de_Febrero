set seed 1234

drop if ID_institución==27

*==================================================*
* MATCHING EXACTO POR ZONA + MAHALANOBIS
* con chequeo de balance posterior
*==================================================*

*--------------------------------------------------*
* 0. Preparación
*--------------------------------------------------*

capture drop _weight _n1 _nn _id _pscore 
capture drop matched_sample control_usado grupo_match
capture drop _id _nn _n1 _weight _pscore _treated _support _common
capture drop seleccionado
sort ID_institución

* Excluir el maternal
drop if Nombre_institución == "Jardín municipal maternal Ternuritas"

* Guardar base original
tempfile base_original
save `base_original', replace

*--------------------------------------------------*
* 1. Matching por zona
*--------------------------------------------------*

use `base_original', clear
levelsof zona, local(zonas)

foreach z of local zonas {

    di "--------------------------------------"
    di "Procesando zona = `z'"
    di "--------------------------------------"

    preserve
        keep if zona == `z'

        * Dejar solo casos completos para las 3 variables
        keep if !missing(tratamiento, tasa_variacion, matricula_total, vulnerabilidad)

        quietly count if tratamiento == 1
        local nt = r(N)

        quietly count if tratamiento == 0
        local nc = r(N)

        di "Tratados completos: `nt'"
        di "Controles completos: `nc'"

        * Solo intentar matching si hay al menos 1 tratado y 1 control
        if (`nt' >= 1 & `nc' >= 1) {

            *--------------------------------------*
            * Intento 1: 3 variables
            *--------------------------------------*
            capture noisily psmatch2 tratamiento, ///
                mahal(tasa_variacion matricula_total vulnerabilidad) ///
                neighbor(1)
				
            if _rc == 0 {
                di "Matching exitoso en zona `z' con 3 variables"

                gen seleccionado = 0
                replace seleccionado = 1 if tratamiento == 1
                replace seleccionado = 1 if tratamiento == 0 & _weight > 0

                keep if seleccionado == 1
                keep Nombre_institución zona tratamiento _weight

                tempfile zona`z'
                save `zona`z'', replace
            }
            else {
                di "Fallo con 3 variables en zona `z'. Probando con 2 variables..."

                *--------------------------------------*
                * Intento 2: 2 variables
                *--------------------------------------*
                use `base_original', clear
                keep if zona == `z'
                keep if !missing(tratamiento, tasa_variacion, matricula_total)

                quietly count if tratamiento == 1
                local nt2 = r(N)

                quietly count if tratamiento == 0
                local nc2 = r(N)

                di "Tratados completos (2 vars): `nt2'"
                di "Controles completos (2 vars): `nc2'"

                if (`nt2' >= 1 & `nc2' >= 1) {

                    capture noisily psmatch2 tratamiento, ///
                        mahal(tasa_variacion matricula_total) ///
                        neighbor(1)

                    if _rc == 0 {
                        di "Matching exitoso en zona `z' con 2 variables"

                        gen seleccionado = 0
                        replace seleccionado = 1 if tratamiento == 1
                        replace seleccionado = 1 if tratamiento == 0 & _weight > 0

                        keep if seleccionado == 1
                        keep Nombre_institución zona tratamiento _weight

                        tempfile zona`z'
                        save `zona`z'', replace
                    }
                    else {
                        di "No se pudo correr matching en zona `z' ni con 3 ni con 2 variables."
                    }
                }
                else {
                    di "Zona `z' omitida: no hay suficientes casos completos ni siquiera con 2 variables."
                }
            }
        }
        else {
            di "Zona `z' omitida: no hay suficientes tratados o controles completos."
        }
    restore
}

*--------------------------------------------------*
* 2. Unir las zonas que sí matchearon
*--------------------------------------------------*

clear
local primero = 1

foreach z of local zonas {
    capture confirm file `zona`z''
    if !_rc {
        if `primero' == 1 {
            use `zona`z'', clear
            local primero = 0
        }
        else {
            append using `zona`z''
        }
    }
}

tempfile matched_total
save `matched_total', replace

*--------------------------------------------------*
* 3. Marcar muestra matched en la base original
*--------------------------------------------------*

use `base_original', clear

gen matched_sample = 0
gen control_usado = 0
gen grupo_match = tratamiento

merge 1:m Nombre_institución zona tratamiento using `matched_total'

replace matched_sample = 1 if _merge == 3
replace control_usado = 1 if _merge == 3 & tratamiento == 0

drop _merge

di "=== Tratadas seleccionadas ==="
list Nombre_institución zona if matched_sample == 1 & tratamiento == 1, noobs sepby(zona)

di "=== Controles seleccionados ==="
list Nombre_institución zona _weight if control_usado == 1, noobs sepby(zona)

*--------------------------------------------------*
* 4. Tabla de balance posterior
*--------------------------------------------------*

preserve
keep if matched_sample == 1

tempfile tabla_balance
postfile handle ///
    str40 variable ///
    mean_control mean_tratada std_diff p_value ///
    using `tabla_balance', replace

local vars vulnerabilidad recibe_refuerzo tiene_patio tiene_material tiene_cocina ///
banos_total2 biblioteca cantidad_salas tiene_2_3 tiene_4_5 tiene_multi tiene_temprano ///
matricula_total docentes_total matricula_prom docentes_prom tasa_variacion tasa_variacion_prom ///
prop_ninas edad_doc antig_doc aprendizaje Edad_director Participación_capacitación_docen ///
antig_dir_anios antig_lab_anios dir_lic dir_prof dir_dipl antig_jardin

foreach v of local vars {

    quietly summarize `v' if tratamiento == 0
    local mc = r(mean)
    local sdc = r(sd)

    quietly summarize `v' if tratamiento == 1
    local mt = r(mean)
    local sdt = r(sd)

    local sdpool = sqrt((`sdt'^2 + `sdc'^2)/2)

    if `sdpool' > 0 {
        local smd = (`mt' - `mc') / `sdpool'
    }
    else {
        local smd = .
    }

    capture quietly ttest `v', by(tratamiento)
    if _rc == 0 {
        local p = r(p)
    }
    else {
        local p = .
    }

    post handle ("`v'") (`mc') (`mt') (`smd') (`p')
}

postclose handle

use `tabla_balance', clear

rename variable Variable
rename mean_control Media_control
rename mean_tratada Media_tratada
rename std_diff Diferencia_estandarizada
rename p_value P_value

format Media_control Media_tratada Diferencia_estandarizada P_value %9.3f

export excel using "balance_post_matching_zona_mahal.xlsx", firstrow(variables) replace

restore

* Veo emparejamiento exacto en zona 1

list ID_institución tratamiento _weight if _weight==1, noobs


* Balance global zona 1 (hay algo raro porque no da igual que arriba -ojo ver)
preserve
keep if zona==1
keep if !missing(tratamiento, tasa_variacion, matricula_total, vulnerabilidad)

gen id_obs = _n

psmatch2 tratamiento, mahal(tasa_variacion matricula_total vulnerabilidad) neighbor(1)
pstest tasa_variacion matricula_total vulnerabilidad, both

list ID_institución tratamiento _weight if _weight==1, noobs
restore

* Como no dio bien el matching en la zona 2, se hace manual:
preserve
keep if zona==2

* identificar la tratada
summarize tasa_variacion if tratamiento==1
local t_tv = r(mean)

summarize matricula_total if tratamiento==1
local t_mat = r(mean)

summarize vulnerabilidad if tratamiento==1
local t_vul = r(mean)

* calcular distancia simple
gen dist = .
replace dist = ///
    abs(tasa_variacion - `t_tv') + ///
    abs(matricula_total - `t_mat') + ///
    abs(vulnerabilidad - `t_vul') ///
    if tratamiento==0

* ordenar por cercanía
sort dist

list Nombre_institución tasa_variacion matricula_total vulnerabilidad dist if tratamiento==0, noobs

restore


// Balance con los controles elegidos: 6, 21, 22 y 23

*--------------------------------------------------*
* 4. Tabla de balance final
*--------------------------------------------------*

preserve
rename tratamiento T_original
gen tratamiento=1 if T_original==1
replace tratamiento=0 if ID_institución==6 | ID_institución==21 | ID_institución==22 | ID_institución==23

keep if tratamiento != .

tempfile tabla_balance
postfile handle ///
    str40 variable ///
    mean_control mean_tratada std_diff p_value ///
    using `tabla_balance', replace

local vars vulnerabilidad recibe_refuerzo tiene_patio tiene_material tiene_cocina ///
banos_total2 biblioteca cantidad_salas tiene_2_3 tiene_4_5 tiene_multi tiene_temprano ///
matricula_total docentes_total matricula_prom docentes_prom tasa_variacion tasa_variacion_prom ///
prop_ninas edad_doc antig_doc aprendizaje Edad_director Participación_capacitación_docen ///
antig_dir_anios antig_lab_anios dir_lic dir_prof dir_dipl antig_jardin

foreach v of local vars {

    quietly summarize `v' if tratamiento == 0
    local mc = r(mean)
    local sdc = r(sd)

    quietly summarize `v' if tratamiento == 1
    local mt = r(mean)
    local sdt = r(sd)

    local sdpool = sqrt((`sdt'^2 + `sdc'^2)/2)

    if `sdpool' > 0 {
        local smd = (`mt' - `mc') / `sdpool'
    }
    else {
        local smd = .
    }

    capture quietly ttest `v', by(tratamiento)
    if _rc == 0 {
        local p = r(p)
    }
    else {
        local p = .
    }

    post handle ("`v'") (`mc') (`mt') (`smd') (`p')
}

postclose handle

use `tabla_balance', clear

rename variable Variable
rename mean_control Media_control
rename mean_tratada Media_tratada
rename std_diff Diferencia_estandarizada
rename p_value P_value

format Media_control Media_tratada Diferencia_estandarizada P_value %9.3f

export excel using "balance_post_matching_zona_mahal_final.xlsx", firstrow(variables) replace

restore