	
* ----------------------------------------------------------- *
* 2) Emparejamiento con la data de salas de 4 y 5 unicamente
* ----------------------------------------------------------- *

use "$data_fin/Data_processed.dta", clear 

*** 2.1) Entropy balancing ***

	/*
	Uso Entropy Balancing para ver qué controles son los más relevantes (mayor peso)
	Restringo a los 5 o 6 controles más relevantes.
	Corro de nuevo el balancing para reasignar pesos que sumen 1.
	El matching es a nivel de grupos (a partir de momentos)
	*/

	* Opcion 1: vulnerabilidad, matricula, variacion de matricula. 
ebalance tratamiento vulnerabilidad matricula_total tasa_variacion, targets(1) // NO CONVERGE

	* Opcion 2: vulnerabilidad, matricula
ebalance tratamiento vulnerabilidad matricula_total, targets(1)

	* Opcion 3: vulnerabilidad, variación matricula
ebalance tratamiento vulnerabilidad tasa_variacion, targets(1) // NO CONVERGE

	* Opcion 4: refuerzo alimentario, variación matricula
ebalance tratamiento recibe_refuerzo tasa_variacion, targets(1) // NO CONVERGE

	* Opcion 5: vulnerabilidad, matricula, aprendizaje
ebalance tratamiento vulnerabilidad matricula_total aprendizaje, targets(1) // NO CONVERGE

	* Opcion 6: vulnerabilidad, aprendizaje
ebalance tratamiento vulnerabilidad aprendizaje, targets(1)

	* Opcion 7: vulnerabilidad, aprendizaje, refuerzo alimentario 
ebalance tratamiento recibe_refuerzo aprendizaje matricula_total, targets(1) // NO CONVERGE

	* Opcion 8: matricula, aprendizaje
ebalance tratamiento matricula_total aprendizaje, targets(1) // NO CONVERGE

	* Opcion 9: matricula, aprendizaje
ebalance tratamiento tasa_variacion aprendizaje, targets(1) // NO CONVERGE

	* Opcion 10: vulnerabilidad, matricula, inasistencia 2025
ebalance tratamiento vulnerabilidad matricula_total inasistencia2025, targets(1)

	* Opcion 11: vulnerabilidad, matricula, inasistencia promedio
ebalance tratamiento vulnerabilidad matricula_total inasistencia_prom_años, targets(1)

	* Opcion 11: vulnerabilidad, matricula, inasistencia promedio, nivel educativo
ebalance tratamiento vulnerabilidad matricula_total inasistencia_prom_años max_niv_ed2025, targets(1) // NO CONVERGE

	* Opcion 12: vulnerabilidad, aprendizaje, inasistencia promedio
ebalance tratamiento vulnerabilidad aprendizaje inasistencia_prom_años, targets(1)

	* Opcion 13: nivel educativo, aprendizaje, inasistencia promedio
ebalance tratamiento max_niv_ed2025 aprendizaje inasistencia_prom_años, targets(1)

	* Opcion 14: nivel educativo, aprendizaje, inasistencia promedio, matricula
ebalance tratamiento max_niv_ed2025 aprendizaje inasistencia_prom_años matricula_total, targets(1) // NO CONVERGE

	* Opcion 15: nivel educativo, aprendizaje, matricula
ebalance tratamiento max_niv_ed2025 aprendizaje matricula_total, targets(1) // NO CONVERGE

	* Opcion 16: nivel educativo, aprendizaje, variación matricula
ebalance tratamiento vulnerabilidad aprendizaje tasa_variacion , targets(1) // NO CONVERGE

	* Opcion 17: nivel educativo, aprendizaje
ebalance tratamiento vulnerabilidad aprendizaje
 
	* Opcion 18: nivel educativo, aprendizaje, indce inraestructura
ebalance tratamiento vulnerabilidad aprendizaje infra_indice // NO CONVERGE

	* Opcion 19: nivel educativo, matricula, indce inraestructura
ebalance tratamiento vulnerabilidad matricula_total infra_indice // NO CONVERGE

	* Opcion 20: nivel educativo, matricula, indce inraestructura
ebalance tratamiento vulnerabilidad inasistencia_prom_años infra_indice

** Loop para comparar opciones **
pause on
local vars vulnerabilidad matricula_total aprendizaje tasa_variacion ///
           inasistencia_prom_años max_niv_ed2025 infra_indice
		   
tempfile base resultados
save `base', replace

	* Base vacía para acumular resultados
clear
set obs 0
gen double ID_institucion = .
gen comb_id = .
gen str120 variables = ""
gen double peso = .
save `resultados', replace
	
	* Loop sobre todas las combinaciones de 3
use `base', clear

local n : word count `vars'
local comb_id = 0

forvalues i = 1/`=`n'-2' {
	* Elije la variable 1
    local v1 : word `i' of `vars'
    
    forvalues j = `=`i'+1'/`=`n'-1' {
	* Elije la variable 2
        local v2 : word `j' of `vars'
        
        forvalues k = `=`j'+1'/`n' {
		* Elije la variable 3
            local v3 : word `k' of `vars'
            
            local ++comb_id // sumar 1 al identificador de combinaciones cada vez que entra en una nueva combinación
            di "Corriendo combinacion `comb_id': `v1' `v2' `v3'"
            
            use `base', clear
            drop if missing(tratamiento, `v1', `v2', `v3')
            
            capture noisily ebalance tratamiento `v1' `v2' `v3', targets(1)
            
            * Solo guardar si converge (verificamos el return code del ultimo ebalance a ver si salió bien - 0)
            if _rc == 0 {
				
				capture confirm variable _webal
                
                if !_rc {
                    keep ID_institucion tratamiento _webal
                    rename _webal peso
                    
                    gen comb_id = `comb_id'
                    gen str120 variables = "`v1' `v2' `v3'"
                    
                    append using `resultados'
                    save `resultados', replace
                }
                
            }
        }
    }
}
use `resultados', clear
reshape wide peso variables, i(ID_institucion) j(comb_id)
keep if tratamiento == 0

	* 6 jardnes con mayor peso en cada caso
gsort -peso3
levelsof ID_institucion in 1/6, local(ids_peso3)

gsort -peso7
levelsof ID_institucion in 1/6, local(ids_peso7)

gsort -peso14
levelsof ID_institucion in 1/6, local(ids_peso14)

gsort -peso23
levelsof ID_institucion in 1/6, local(ids_peso23)

gsort -peso29
levelsof ID_institucion in 1/6, local(ids_peso29)

	* Guardo las variables usadas en cada iteración
levelsof variables3, local(variables3)

levelsof variables7, local(variables7)

levelsof variables14, local(variables14)

levelsof variables23, local(variables23)

levelsof variables29, local(variables29)

use `base', clear

	* Genero las indicadoras de variables
gen variables3 = `variables3'
gen variables7 = `variables7'
gen variables14 = `variables14'
gen variables23 = `variables23'
gen variables29 = `variables29'

	* Chequeo los id
di "`ids_peso3'"
di "`ids_peso7'"
di "`ids_peso14'"
di "`ids_peso23'"
di "`ids_peso29'"

	* Genero las dummies de control para cada caso
gen control3  = inlist(ID_institucion, 6, 11, 20, 21, 22, 26)
gen control7  = inlist(ID_institucion, 11, 17, 20, 21, 22, 26)
gen control14 = inlist(ID_institucion, 2, 7, 11, 12, 22, 26)
gen control23 = inlist(ID_institucion, 2, 5, 6, 15, 17, 26)
gen control29 = inlist(ID_institucion, 6, 11, 15, 17, 20, 26) 

gen cantidad_control = control3 + control7 + control14 + control23 + control29 // cantidad de veces que una unidad aparece como control

	* Tabla para comparar las medias
pause on
preserve
local xvars inasistencia2023 inasistencia2024 inasistencia2025 max_niv_ed2025 inasistencia_prom_años ///
			matricula_total docentes_total prop_ninas edad_doc antig_doc formacion_doc aprendizaje ///
			cantidad_salas Edad_director vulnerabilidad antig_jardin infra_indice
			
local controls control3 control7 control14 control23 control29

tempfile resultados

postfile handle str12 control_var str40 variable ///
    double mean_1 mean_0 diff smd using `resultados', replace

foreach c of local controls {
    foreach v of local xvars {
        
		* media de los tratados
        quietly summarize `v' if tratamiento == 1
        local m1 = r(mean)
        local var1 = r(Var)
        
		* media de los controles
        quietly summarize `v' if `c' == 1
        local m0 = r(mean)
        local var0 = r(Var)
		
		* diferencia tratados - conttoles
        local d = `m1' - `m0' 
        local smd = (`m1' - `m0') / sqrt((`var1' + `var0')/2)
        
        post handle ("`c'") ("`v'") (`m1') (`m0') (`d') (`smd')
    }
}

postclose handle

use `resultados', clear
*pause

reshape wide mean_1 mean_0 diff smd, i(variable) j(control_var) string
*pause

export excel using "$out_folder/tabla_entropy_balance.xlsx", firstrow(variables) replace
*pause
restore

	* El nivel educativo y indice de infraestructura da distinto en el mejor control (control3), exploramos por qué
sum max_niv_ed2025 if control3==1, detail
sum max_niv_ed2025 if tratamiento==1, detail

tab  max_niv_ed2025 if control3==1
tab  max_niv_ed2025 if tratamiento==1

tab  banos_total2 if control3==1
tab  banos_total2 if tratamiento==1 // la mayor diferencia esta en la cantidad de baños

tab  tiene_patio if control3==1
tab  tiene_patio if tratamiento==1

tab  biblioteca if control3==1
tab  biblioteca if tratamiento==1


*** 2.2) Matching a nivel de grupos manual (priorizando o no vulnerabilidad / zona)***

/* 
   Paso 1: Priorizamos el emparejamiento en vulnerabilidad, matrícula y aprendizaje
	
   Generamos todas las combinaciones posibles de 6 controles entre las unidades no tratadas. 
   Para cada una, se calcula la diferencia de medias estandarizada (SMD) entre tratados y controles en un conjunto de covariables. 
   El desbalance de cada combinación se resume usando la SMD máxima y la suma total de SMD
   Se guardan los resultados y se ordenan las combinaciones priorizando menor desbalance máximo. 
   Imponemos la condición de que ningun desvio sea mayor a |0,25|
*/

use "$data_fin/Data_processed.dta", clear 

	* A) Definir candidatos a control: todos los no tratados
levelsof ID_institucion if tratamiento == 0, local(ctrl_all)

display "`ctrl_all'"
	
	* B) Variables de balance
*local vars inasistencia2023 inasistencia2024 inasistencia2025 inasistencia_prom_años max_niv_ed2025  ///
		   matricula_total docentes_total prop_ninas edad_doc antig_doc formacion_doc aprendizaje ///
		   Edad_director vulnerabilidad recibe_refuerzo antig_jardin antig_dir_anios antig_lab_anios  ///
		   dir_lic dir_prof dir_dipl Participación_capacitación_docen tiene_patio tiene_material ///
		   tiene_cocina banos_total2 biblioteca cantidad_salas tasa_variacion infra_indice
			 
local vars matricula_total vulnerabilidad aprendizaje
			 
	* C) Archivo para guardar resultados
tempfile resultados_match6
tempname memhold

postfile `memhold' str100 controles double suma_smd max_smd using `resultados_match6', replace

	* D) Loop sobre todas las combinaciones posibles de 6 controles
foreach a of local ctrl_all {
    foreach b of local ctrl_all {
        foreach c of local ctrl_all {
            foreach d of local ctrl_all {
                foreach e of local ctrl_all {
                    foreach f of local ctrl_all {

                        * evitar repeticiones y permutaciones
                        if (`a' < `b' & `b' < `c' & `c' < `d' & `d' < `e' & `e' < `f') {

                            preserve
								* creo un grupo temporal con 4 tratados y 6 controles
                                gen grupo_tmp = .
                                replace grupo_tmp = 1 if tratamiento == 1
                                replace grupo_tmp = 0 if inlist(ID_institucion, `a', `b', `c', `d', `e', `f')
								
								* eliminamos el resto de las obs
                                keep if grupo_tmp < .
								
								* locales para guardar la suma de diferencias estandarizadas y la peor diferencia estandarizada
                                local suma = 0
                                local maximo = 0
								local valido = 1

                                foreach v of local vars {

                                    quietly summarize `v' if grupo_tmp == 0
                                    local mc = r(mean)
                                    local sdc = r(sd)

                                    quietly summarize `v' if grupo_tmp == 1
                                    local mt = r(mean)
                                    local sdt = r(sd)

                                    local sdpool = sqrt((`sdt'^2 + `sdc'^2)/2)

                                    if `sdpool' > 0 {
                                        local smd = abs((`mt' - `mc') / `sdpool')
										* chequear umbral
										if `smd' > 0.25 {
											local valido = 0
											}
										
                                        local suma = `suma' + `smd'

                                        if `smd' > `maximo' {
                                            local maximo = `smd'
                                        }
                                    }
                                }

                                local combo "`a' `b' `c' `d' `e' `f'"
								
                                if `valido' == 1 {
									post `memhold' ("`combo'") (`suma') (`maximo')
									}
                            restore
                        }
                    }
                }
            }
        }
    }
}

postclose `memhold'

	* E) Ver mejores combinaciones
use `resultados_match6', clear
sort max_smd suma_smd

list in 1/20, noobs

/* 
   Paso 2: De las combinaciones posibles, vemos cual tiene menor diferencia en el resto de las variables
	
   Generamos todas las combinaciones posibles de 6 controles entre las unidades no tratadas. 
   Para cada una, se calcula la diferencia de medias estandarizada (SMD) entre tratados y controles en un conjunto de covariables. 
   El desbalance de cada combinación se resume usando la SMD máxima y la suma total de SMD
   Se guardan los resultados y se ordenan las combinaciones priorizando menor desbalance máximo. 
   Imponemos la condición de que ningun desvio sea mayor a |0,25|
*/

use "$data_fin/Data_processed.dta", clear 

* A) Lista larga de variables para el paso 2
local vars inasistencia2023 inasistencia2024 inasistencia2025 inasistencia_prom_años max_niv_ed2025 ///
           docentes_total prop_ninas edad_doc antig_doc formacion_doc ///
           Edad_director recibe_refuerzo antig_jardin antig_dir_anios antig_lab_anios ///
           dir_lic dir_prof dir_dipl Participación_capacitación_docen tiene_patio tiene_material ///
           tiene_cocina banos_total2 biblioteca cantidad_salas tasa_variacion infra_indice

* B) Guardar resultados
tempfile resultados_paso2
tempname memhold

postfile `memhold' str100 controles double suma_smd max_smd using `resultados_paso2', replace

* C) Evaluar solo las combinaciones finalistas del paso 1
local combos ///
    "6 11 20 21 22 26" ///
    "6 11 15 20 22 26" ///
    "6 11 15 20 21 26" ///
    "6 11 17 20 22 26"

foreach combo in ///
    "6 11 20 21 22 26" ///
    "6 11 15 20 22 26" ///
    "6 11 15 20 21 26" ///
    "6 11 17 20 22 26" {

    tokenize `"`combo'"'
    local a `1'
    local b `2'
    local c `3'
    local d `4'
    local e `5'
    local f `6'

    preserve
        gen grupo_tmp = .
        replace grupo_tmp = 1 if tratamiento == 1
        replace grupo_tmp = 0 if inlist(ID_institucion, `a', `b', `c', `d', `e', `f')

        keep if grupo_tmp < .

        local suma = 0
        local maximo = 0

        foreach v of local vars {

            quietly summarize `v' if grupo_tmp == 0
            local mc = r(mean)
            local sdc = r(sd)

            quietly summarize `v' if grupo_tmp == 1
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

        post `memhold' ("`combo'") (`suma') (`maximo')
    restore
}

postclose `memhold'

use `resultados_paso2', clear
sort max_smd suma_smd

** Vuelvo a la data final para crear la tabla de comparacion de medias
	
use "$data_fin/Data_processed.dta", clear 

	* Genero las dummies de control para cada caso
gen control1 = inlist(ID_institucion, 6, 11, 20, 21, 22, 26)
gen control2 = inlist(ID_institucion, 6, 11, 15, 20, 22, 26)
gen control3 = inlist(ID_institucion, 6, 11, 15, 20, 21, 26)
gen control4 = inlist(ID_institucion, 6, 11, 17, 20, 22, 26)

gen cantidad_control = control1 + control2 + control3 + control4  // cantidad de veces que una unidad aparece como control

	* Tabla para comparar las medias
local xvars inasistencia2023 inasistencia2024 inasistencia2025 inasistencia_prom_años max_niv_ed2025 ///
            docentes_total prop_ninas edad_doc antig_doc formacion_doc ///
            Edad_director recibe_refuerzo antig_jardin antig_dir_anios antig_lab_anios ///
            dir_lic dir_prof dir_dipl Participación_capacitación_docen tiene_patio tiene_material ///
            tiene_cocina banos_total2 biblioteca cantidad_salas tasa_variacion infra_indice ///
			vulnerabilidad matricula_total aprendizaje
			
local controls control1 control2 control3 control4

tempfile resultados_medias

postfile handle str12 control_var str40 variable ///
    double mean_1 mean_0 diff smd using `resultados_medias', replace

foreach c of local controls {
	di "control `c'"
	
    foreach v of local xvars {
		di "variable `v'"
        
		* media de los tratados
        quietly summarize `v' if tratamiento == 1
        local m1 = r(mean)
        local var1 = r(Var)
        
		* media de los controles
        quietly summarize `v' if `c' == 1
        local m0 = r(mean)
        local var0 = r(Var)
		
		* diferencia tratados - conttoles
        local d = `m1' - `m0' 
        local smd = (`m1' - `m0') / sqrt((`var1' + `var0')/2)
        
        post handle ("`c'") ("`v'") (`m1') (`m0') (`d') (`smd')
    }
}

postclose handle

use `resultados_medias', clear

reshape wide mean_1 mean_0 diff smd, i(variable) j(control_var) string

export excel using "$out_folder/tabla_balance_bes_subset.xlsx", firstrow(variables) replace

** Entropy balancing con la mejor opción: control 4
use "$data_fin/Data_processed.dta", clear 
gen control4 = inlist(ID_institucion, 6, 11, 17, 20, 22, 26)
keep if control4 == 1 | tratamiento == 1

ebalance tratamiento max_niv_ed2025 infra_indice inasistencia2025 prop_ninas, targets(1) // no converge
ebalance tratamiento max_niv_ed2025 infra_indice inasistencia2025 , targets(1) // no converge
ebalance tratamiento max_niv_ed2025 infra_indice , targets(1) // no converge
ebalance tratamiento infra_indice max_niv_ed2025 , targets(1) // no converge


ebalance tratamiento max_niv_ed2025 inasistencia2025 , targets(1)
ebalance tratamiento infra_indice inasistencia2025 , targets(1)

ebalance tratamiento max_niv_ed2025 , targets(1)
table tratamiento [aw=_webal], statistic(mean vulnerabilidad matricula_total aprendizaje max_niv_ed2025) // no sirve, desalancea lo importante


*** 2.3) Matching a nivel de individual manual (con y sin reemplazo; priorizando o no vulnerabilidad / zona) ***

	
