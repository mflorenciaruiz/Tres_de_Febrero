// Camibar el main según el usuario:
global main "/Users/florenciaruiz/Library/Mobile Documents/com~apple~CloudDocs/RA Maria/Tres de Febrero/Tres_de_Febrero/Procesamiento de datos"

global data_folder "$main/Datos"
global out_folder  "$main/Output"
global data_raw "$data_folder/Raw"
global data_int "$data_folder/Intermediate"
global data_fin "$data_folder/Final"


* ----------------------------------------------------------- *
*       Emparejamiento turno mañana, salas 4 y 5
* ----------------------------------------------------------- *

*** 1) Matching a nivel de grupos manual ***

/* 
   Paso 1: Priorizamos el emparejamiento en vulnerabilidad, matrícula y aprendizaje
	
   Generamos todas las combinaciones posibles de 6 controles entre las unidades no tratadas. 
   Para cada una, se calcula la diferencia de medias estandarizada (SMD) entre tratados y controles en un conjunto de covariables. 
   El desbalance de cada combinación se resume usando la SMD máxima y la suma total de SMD
   Se guardan los resultados y se ordenan las combinaciones priorizando menor desbalance máximo. 
   Imponemos la condición de que ningun desvio sea mayor a |0,25|
*/

** 1.1) Priorizamos matricula_total vulnerabilidad aprendizaje

use "$data_fin/Data_processed_tm.dta", clear 

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

// salio solo un control: 6 12 17 20 22 26

** Vuelvo a la data final para crear la tabla de comparacion de medias
use "$data_fin/Data_processed_tm.dta", clear 

	* Genero las dummies de control para cada caso
gen control = inlist(ID_institucion, 6, 12, 17, 20, 22, 26)

	* Tabla para comparar las medias
local xvars inasistencia2023 inasistencia2024 inasistencia2025 inasistencia_prom_años max_niv_ed2025 ///
            docentes_total prop_ninas edad_doc antig_doc formacion_doc ///
            Edad_director recibe_refuerzo antig_jardin antig_dir_anios antig_lab_anios ///
            dir_lic dir_prof dir_dipl Participación_capacitación_docen tiene_patio tiene_material ///
            tiene_cocina banos_total2 biblioteca cantidad_salas tasa_variacion infra_indice ///
			vulnerabilidad matricula_total aprendizaje

tempfile resultados_medias

postfile handle str40 variable ///
    double mean_1 mean_0 diff smd using `resultados_medias', replace
	
foreach v of local xvars {
	di "variable `v'"
        
	* media de los tratados
    quietly summarize `v' if tratamiento == 1
    local m1 = r(mean)
    local var1 = r(Var)
        
	* media de los controles
    quietly summarize `v' if control == 1
    local m0 = r(mean)
    local var0 = r(Var)
		
	* diferencia tratados - conttoles
    local d = `m1' - `m0' 
    local smd = (`m1' - `m0') / sqrt((`var1' + `var0')/2)
        
    post handle ("`v'") (`m1') (`m0') (`d') (`smd')
    }

postclose handle

use `resultados_medias', clear

replace smd = 0 if smd ==.

export excel using "$out_folder/tabla_balance_bes_subset_tm.xlsx", firstrow(variables) replace

* chequeo las salas del control que salio
use "$data_fin/Data_processed_tm.dta", clear 
tab tiene_sala4 tiene_sala5
tab tiene_sala4 tiene_sala5 if tratamiento ==0
keep if ID_institucion==6|ID_institucion==12|ID_institucion==17|ID_institucion== 20|ID_institucion== 22 |ID_institucion==26
br ID_institucion cantidad_salas tiene_sala4 tiene_sala5
// hay 5 jardines en total que no tienen sala de 4. De esos 5, hay 4 que se seleccionan como control.

** 1.2) Priorizamos matricula_total vulnerabilidad inasistencia

use "$data_fin/Data_processed_tm.dta", clear 

	* A) Definir candidatos a control: todos los no tratados
levelsof ID_institucion if tratamiento == 0, local(ctrl_all)

display "`ctrl_all'"
	
	* B) Variables de balance 
local vars matricula_total vulnerabilidad inasistencia2025
			 
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

// salio solo un control: 6 11 20 21 22 26

** Vuelvo a la data final para crear la tabla de comparacion de medias
use "$data_fin/Data_processed_tm.dta", clear 

	* Genero las dummies de control para cada caso
gen control = inlist(ID_institucion, 6, 11, 20, 21, 22, 26)

	* Tabla para comparar las medias
local xvars inasistencia2023 inasistencia2024 inasistencia2025 inasistencia_prom_años max_niv_ed2025 ///
            docentes_total prop_ninas edad_doc antig_doc formacion_doc ///
            Edad_director recibe_refuerzo antig_jardin antig_dir_anios antig_lab_anios ///
            dir_lic dir_prof dir_dipl Participación_capacitación_docen tiene_patio tiene_material ///
            tiene_cocina banos_total2 biblioteca cantidad_salas tasa_variacion infra_indice ///
			vulnerabilidad matricula_total aprendizaje

tempfile resultados_medias

postfile handle str40 variable ///
    double mean_1 mean_0 diff smd using `resultados_medias', replace
	
foreach v of local xvars {
	di "variable `v'"
        
	* media de los tratados
    quietly summarize `v' if tratamiento == 1
    local m1 = r(mean)
    local var1 = r(Var)
        
	* media de los controles
    quietly summarize `v' if control == 1
    local m0 = r(mean)
    local var0 = r(Var)
		
	* diferencia tratados - conttoles
    local d = `m1' - `m0' 
    local smd = (`m1' - `m0') / sqrt((`var1' + `var0')/2)
        
    post handle ("`v'") (`m1') (`m0') (`d') (`smd')
    }

postclose handle

use `resultados_medias', clear

replace smd = 0 if smd ==.

export excel using "$out_folder/tabla_balance_bes_subset_tm_inasis.xlsx", firstrow(variables) replace

* chequeo las salas del control que salio
use "$data_fin/Data_processed_tm.dta", clear 
tab tiene_sala4 tiene_sala5
tab tiene_sala4 tiene_sala5 if tratamiento==1
keep if ID_institucion==6|ID_institucion==11|ID_institucion==20|ID_institucion== 21|ID_institucion== 22 |ID_institucion==26
br ID_institucion cantidad_salas tiene_sala4 tiene_sala5
// hay 5 jardines en total que no tienen sala de 4. De esos 5, hay 4 que se seleccionan como control.
// La unica forma de balancear las salas (tener un control con misma proporcion de salas de 4 y 5 que tratados -40% aprox), es resignar similitud (en el primer paso)

*** 2) Matching a nivel de individual manual ***

/*
	Matching automático: elegimos dos vecinos con reemplazo, después nos quedamos con 6.
*/

** 2.1) Priorizamos matricula_total vulnerabilidad aprendizaje

use "$data_fin/Data_processed_tm.dta", clear 

* A) Corro el matching
	
psmatch2 tratamiento, mahal(vulnerabilidad matricula_total aprendizaje) neighbor(2)
describe _*
	* Medias sin el matching
table tratamiento, statistic(mean vulnerabilidad matricula_total aprendizaje)
	* Medias con el matching
table _treated [aw=_weight], statistic(mean vulnerabilidad matricula_total aprendizaje)

br ID_institucion tratamiento _treated _weight _id _n1 _n2 _nn
sort tratamiento

	* Veo que controles elige
levelsof ID_institucion if _treated==0 & _weight!=., local(controles)
display "`controles'" // 6 17 20 22 26 (6 22 y 26 con reemplazo)

* B) Tabla para comparar las medias
local xvars inasistencia2023 inasistencia2024 inasistencia2025 inasistencia_prom_años max_niv_ed2025 ///
            docentes_total prop_ninas edad_doc antig_doc formacion_doc ///
            Edad_director recibe_refuerzo antig_jardin antig_dir_anios antig_lab_anios ///
            dir_lic dir_prof dir_dipl Participación_capacitación_docen tiene_patio tiene_material ///
            tiene_cocina banos_total2 biblioteca cantidad_salas tasa_variacion infra_indice ///
			vulnerabilidad matricula_total aprendizaje
			
tempfile resultados_medias2 base
save `base', replace

postfile handle2 str40 variable double mean_1 mean_0 diff smd using `resultados_medias2', replace

foreach v of local xvars {
    
    * tratadas
    quietly su `v' if _treated==1
    local mt = r(mean)
    local vt = r(Var)

    * controles ponderados
    quietly su `v' [aw=_weight] if _treated==0
    local mc = r(mean)
    local vc = r(Var)

    * difernecia y SMD
	local d = `mt' - `mc' 
    local smd = (`mt' - `mc') / sqrt((`vt' + `vc')/2)

	 post handle2  ("`v'") (`mt') (`mc') (`d') (`smd')
}
postclose handle2
use `resultados_medias2', clear
replace smd =0 if smd==.
export excel using "$out_folder/tabla_balance_matching_tm.xlsx", firstrow(variables) replace

* chequeo las salas del control que salio
use "$data_fin/Data_processed_tm.dta", clear 
keep if ID_institucion==6|ID_institucion==17|ID_institucion==20|ID_institucion== 22|ID_institucion==26
br ID_institucion cantidad_salas tiene_sala4 tiene_sala5
// solo uno de los controles seleccionados tiene sala de 4

** 2.2) Priorizamos matricula_total vulnerabilidad inasistencia

use "$data_fin/Data_processed_tm.dta", clear 

* A) Corro el matching
	
psmatch2 tratamiento, mahal(vulnerabilidad matricula_total inasistencia2025) neighbor(2)
describe _*
	* Medias sin el matching
table tratamiento, statistic(mean vulnerabilidad matricula_total aprendizaje inasistencia2025)
	* Medias con el matching
table _treated [aw=_weight], statistic(mean vulnerabilidad matricula_total aprendizaje inasistencia2025)

br ID_institucion tratamiento _treated _weight _id _n1 _n2 _nn
sort tratamiento

	* Veo que controles elige
levelsof ID_institucion if _treated==0 & _weight!=., local(controles)
display "`controles'" // 6 11 20 21 22 24 26 (6 reemplazo)

	* chequeo las salas del control que salio
preserve
use "$data_fin/Data_processed_tm.dta", clear 
keep if ID_institucion==6|ID_institucion==11|ID_institucion==20|ID_institucion== 21|ID_institucion== 22|ID_institucion==24|ID_institucion== 26
br ID_institucion cantidad_salas tiene_sala4 tiene_sala5
restore
// 4 de los 7 controles solo tienen sala de 5

* B) Saco un control iterando, para tener 6. Solo saco controles con peso 0.5 que no tienen sala de 4

	* Potenciales controles a eliminar
levelsof ID_institucion if _treated==0 & _weight==0.5 & tiene_sala4==0, local(controles)
display "`controles'"

local xvars inasistencia2023 inasistencia2024 inasistencia2025 inasistencia_prom_años max_niv_ed2025 ///
            docentes_total prop_ninas edad_doc antig_doc formacion_doc ///
            Edad_director recibe_refuerzo antig_jardin antig_dir_anios antig_lab_anios ///
            dir_lic dir_prof dir_dipl Participación_capacitación_docen tiene_patio tiene_material ///
            tiene_cocina banos_total2 biblioteca cantidad_salas tasa_variacion infra_indice ///
            vulnerabilidad matricula_total aprendizaje

tempfile resultados_medias3

postfile handle3 str40 variable str20 escenario double mean_1 mean_0 diff smd using `resultados_medias3', replace

	* loop sobre controles a eliminar
foreach c of local controles {

    di "Sacando control `c'"

    preserve

    * eliminar ese control
    drop if ID_institucion == `c'

    foreach v of local xvars {
        
        * tratadas
        quietly su `v' if _treated==1
        local mt = r(mean)
        local vt = r(Var)

        * controles ponderados (sin ese control)
        quietly su `v' [aw=_weight] if _treated==0
        local mc = r(mean)
        local vc = r(Var)

        * diferencia y SMD
        local d = `mt' - `mc' 
        local smd = (`mt' - `mc') / sqrt((`vt' + `vc')/2)

        post handle3 ("`v'") ("drop_`c'") (`mt') (`mc') (`d') (`smd')
    }

    restore
}

postclose handle3

use `resultados_medias3', clear
replace smd =0 if smd==.
reshape wide mean_1 mean_0 diff smd, i(variable) j(escenario) string

export excel using "$out_folder/tabla_balance_matching_eliminando_tm.xlsx", firstrow(variables) replace

** 1.3) Priorizamos matricula_total vulnerabilidad salas aprendizaje

use "$data_fin/Data_processed_tm.dta", clear 

* A) Corro el matching
	
psmatch2 tratamiento, mahal(vulnerabilidad matricula_total aprendizaje tiene_sala4) neighbor(2)
describe _*
	* Medias sin el matching
table tratamiento, statistic(mean vulnerabilidad matricula_total aprendizaje tiene_sala4)
	* Medias con el matching
table _treated [aw=_weight], statistic(mean vulnerabilidad matricula_total aprendizaje tiene_sala4)

br ID_institucion tratamiento _treated _weight _id _n1 _n2 _nn
sort tratamiento

	* Veo que controles elige
levelsof ID_institucion if _treated==0 & _weight!=., local(controles)
display "`controles'" // 15 17 20 21 22 (21 y 15 con reemplazo; 21 3 veces; 15 2 veces)

* B) Tabla para comparar las medias
local xvars inasistencia2023 inasistencia2024 inasistencia2025 inasistencia_prom_años max_niv_ed2025 ///
            docentes_total prop_ninas edad_doc antig_doc formacion_doc ///
            Edad_director recibe_refuerzo antig_jardin antig_dir_anios antig_lab_anios ///
            dir_lic dir_prof dir_dipl Participación_capacitación_docen tiene_patio tiene_material ///
            tiene_cocina banos_total2 biblioteca cantidad_salas tasa_variacion infra_indice ///
			vulnerabilidad matricula_total aprendizaje
			
tempfile resultados_medias2 base
save `base', replace

postfile handle2 str40 variable double mean_1 mean_0 diff smd using `resultados_medias2', replace

foreach v of local xvars {
    
    * tratadas
    quietly su `v' if _treated==1
    local mt = r(mean)
    local vt = r(Var)

    * controles ponderados
    quietly su `v' [aw=_weight] if _treated==0
    local mc = r(mean)
    local vc = r(Var)

    * difernecia y SMD
	local d = `mt' - `mc' 
    local smd = (`mt' - `mc') / sqrt((`vt' + `vc')/2)

	 post handle2  ("`v'") (`mt') (`mc') (`d') (`smd')
}
postclose handle2
use `resultados_medias2', clear
replace smd =0 if smd==.
export excel using "$out_folder/tabla_balance_matching_tm_sala4.xlsx", firstrow(variables) replace

* chequeo las salas del control que salio
use "$data_fin/Data_processed_tm.dta", clear 
keep if ID_institucion==15|ID_institucion==17|ID_institucion==20|ID_institucion== 21|ID_institucion==22
br ID_institucion cantidad_salas tiene_sala4 tiene_sala5
// dos de los controles no tiene sala de 4


** 1.4) Priorizamos matricula_total vulnerabilidad salas

use "$data_fin/Data_processed_tm.dta", clear 

* A) Corro el matching
	
psmatch2 tratamiento, mahal(vulnerabilidad matricula_total tiene_sala4) neighbor(2)
describe _*
	* Medias sin el matching
table tratamiento, statistic(mean vulnerabilidad matricula_total aprendizaje tiene_sala4)
	* Medias con el matching
table _treated [aw=_weight], statistic(mean vulnerabilidad matricula_total aprendizaje tiene_sala4)

br ID_institucion tratamiento _treated _weight _id _n1 _n2 _nn
sort tratamiento

	* Veo que controles elige
levelsof ID_institucion if _treated==0 & _weight!=., local(controles)
display "`controles'" // 11 15 20 21 22 (21 y 15 con reemplazo; 21 3 veces; 15 2 veces)

* B) Tabla para comparar las medias
local xvars inasistencia2023 inasistencia2024 inasistencia2025 inasistencia_prom_años max_niv_ed2025 ///
            docentes_total prop_ninas edad_doc antig_doc formacion_doc ///
            Edad_director recibe_refuerzo antig_jardin antig_dir_anios antig_lab_anios ///
            dir_lic dir_prof dir_dipl Participación_capacitación_docen tiene_patio tiene_material ///
            tiene_cocina banos_total2 biblioteca cantidad_salas tasa_variacion infra_indice ///
			vulnerabilidad matricula_total aprendizaje
			
tempfile resultados_medias2 base
save `base', replace

postfile handle2 str40 variable double mean_1 mean_0 diff smd using `resultados_medias2', replace

foreach v of local xvars {
    
    * tratadas
    quietly su `v' if _treated==1
    local mt = r(mean)
    local vt = r(Var)

    * controles ponderados
    quietly su `v' [aw=_weight] if _treated==0
    local mc = r(mean)
    local vc = r(Var)

    * difernecia y SMD
	local d = `mt' - `mc' 
    local smd = (`mt' - `mc') / sqrt((`vt' + `vc')/2)

	 post handle2  ("`v'") (`mt') (`mc') (`d') (`smd')
}
postclose handle2
use `resultados_medias2', clear
replace smd =0 if smd==.
export excel using "$out_folder/tabla_balance_matching_tm_sala4_2.xlsx", firstrow(variables) replace

* chequeo las salas del control que salio
use "$data_fin/Data_processed_tm.dta", clear 
keep if ID_institucion==15|ID_institucion==11|ID_institucion==20|ID_institucion== 21|ID_institucion==22
br ID_institucion cantidad_salas tiene_sala4 tiene_sala5
// dos de los controles no tiene sala de 4

