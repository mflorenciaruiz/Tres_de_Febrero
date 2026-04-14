*==============================*
* 1. Definir tratadas
*==============================*
preserve
gen tratada_fija = inlist(ID_institución, 3, 4, 13, 16)

* Candidatos a control zona 1
gen cand_z1 = inlist(ID_institución, 2, 5, 6, 7, 8, 10, 17, 18, 19, 20, 21, 22)

* Candidatos a control zona 2
gen cand_z2 = inlist(ID_institución, 23, 24, 25, 26)   // ajustar según corresponda

levelsof ID_institución if cand_z1==1, local(ctrl_z1)
levelsof ID_institución if cand_z2==1, local(ctrl_z2)

display "`ctrl_z1'"
display "`ctrl_z2'"

tempname memhold
postfile `memhold' str100 controles double suma_smd max_smd using resultados_match, replace

local vars vulnerabilidad recibe_refuerzo tiene_patio tiene_material tiene_cocina ///
banos_total2 biblioteca cantidad_salas tiene_2_3 tiene_4_5 tiene_multi tiene_temprano ///
matricula_total docentes_total matricula_prom docentes_prom tasa_variacion tasa_variacion_prom ///
prop_ninas edad_doc antig_doc aprendizaje Edad_director Participación_capacitación_docen ///
antig_dir_anios antig_lab_anios dir_lic dir_prof dir_dipl antig_jardin

foreach a of local ctrl_z1 {
    foreach b of local ctrl_z1 {
        foreach c of local ctrl_z1 {

            * asegurar que no se repitan
            if (`a' < `b' & `b' < `c') {

                foreach d of local ctrl_z2 {

                    preserve
                        gen grupo_tmp = .
                        replace grupo_tmp = 1 if tratada_fija==1
                        replace grupo_tmp = 0 if inlist(ID_institución, `a', `b', `c', `d')

                        keep if grupo_tmp < .

                        local suma = 0
                        local maximo = 0

                        foreach v of local vars {

                            quietly summarize `v' if grupo_tmp==0
                            local mc = r(mean)
                            local sdc = r(sd)

                            quietly summarize `v' if grupo_tmp==1
                            local mt = r(mean)
                            local sdt = r(sd)

                            local sdpool = sqrt((`sdt'^2 + `sdc'^2)/2)

                            if `sdpool' > 0 {
                                local smd = abs((`mt' - `mc') / `sdpool')
                                local suma = `suma' + `smd'
                                if `smd' > `maximo' {
                                    local maximo = `smd'
                                }
                            }
                        }

                        local combo "`a' `b' `c' `d'"
                        post `memhold' ("`combo'") (`suma') (`maximo')
                    restore
                }
            }
        }
    }
}

postclose `memhold'

use resultados_match, clear
sort max_smd suma_smd
list in 1/20, noobs

restore

* Balance
gen matched_sample = inlist(ID_institución, 3, 4, 13, 16, 2, 25, 18, 10)

* Indicador de grupo dentro de la muestra matched
gen grupo_match = .
replace grupo_match = 1 if inlist(ID_institución, 3, 4, 13, 16)
replace grupo_match = 0 if inlist(ID_institución, 2, 25, 18, 10)

*label define grupo_match 0 "Control" 1 "Tratada"
label values grupo_match grupo_match

tab matched_sample grupo_match
list ID_institución Nombre_institución grupo_match if matched_sample==1

***** Tabla de diferencia estandaridaza
preserve

* Quedarse solo con la muestra matched
keep if matched_sample==1

* Crear archivo temporal para guardar resultados
tempfile tabla_balance
postfile handle ///
    str40 variable ///
    mean_control mean_tratada std_diff p_value ///
    using `tabla_balance', replace

* Lista de variables
local vars vulnerabilidad recibe_refuerzo tiene_patio tiene_material tiene_cocina ///
banos_total2 biblioteca cantidad_salas tiene_2_3 tiene_4_5 tiene_multi tiene_temprano ///
matricula_total docentes_total matricula_prom docentes_prom tasa_variacion tasa_variacion_prom ///
prop_ninas edad_doc antig_doc aprendizaje Edad_director Participación_capacitación_docen ///
antig_dir_anios antig_lab_anios dir_lic dir_prof dir_dipl antig_jardin

* Loop
foreach v of local vars {

    quietly summarize `v' if grupo_match==0
    local mc = r(mean)
    local sdc = r(sd)

    quietly summarize `v' if grupo_match==1
    local mt = r(mean)
    local sdt = r(sd)

    * Desvío estándar combinado
    local sdpool = sqrt((`sdt'^2 + `sdc'^2)/2)

    * Diferencia estandarizada
    if `sdpool' > 0 {
        local smd = (`mt' - `mc') / `sdpool'
    }
    else {
        local smd = .
    }

    quietly ttest `v', by(grupo_match)
    local p = r(p)

    post handle ("`v'") (`mc') (`mt') (`smd') (`p')
}

postclose handle

* Abrir la base resumen
use `tabla_balance', clear

* Renombrar variables para Excel
rename variable Variable
rename mean_control Media_control
rename mean_tratada Media_tratada
rename std_diff Diferencia_estandarizada
rename p_value P_value

* Formato numérico
format Media_control Media_tratada Diferencia_estandarizada P_value %9.3f

* Exportar a Excel
export excel using "tabla_balance_matching_estand_2.xlsx", firstrow(variables) replace

restore

