** Matching

// Camibar el main según el usuario:
global main "/Users/florenciaruiz/Library/Mobile Documents/com~apple~CloudDocs/RA Maria/Tres de Febrero/Tres_de_Febrero/Procesamiento de datos"
	* global main "ruta/vicky"

global data_folder "$main/Datos"
global out_folder "$main/Output"
global data_raw "$data_folder/Raw"
global data_int "$data_folder/Intermediate"
global data_fin "$data_folder/Final"

use "$data_int/Salas_inst.dta", replace

* ------------------------------------ *
* 1) Matching sin restringir las salas
* ------------------------------------ *

drop formacion_doc
gen matricula_prom=matricula_total/cantidad_salas
gen docentes_prom=docentes_total/cantidad_salas
gen banos_prom=banos_total2/matricula_total
*gen banos_prom=banos_total2/cantidad_salas
egen z_patio = std(tiene_patio)
egen z_biblio = std(biblioteca)
egen z_banos = std(banos_total2)
egen z_banos_prom = std(banos_prom)
egen infra_indice = rowmean(z_patio z_biblio z_banos)
egen infra_indicev1 = rowmean(z_patio z_biblio z_banos_prom)

gen sala_2 = inlist(ID_institución, 2, 5, 9, 15, 17, 19, 24, 27)

merge 1:1 ID_institución using Var_matricula
drop _merge
merge 1:1 ID_institución  using Var_matricula2
drop _merge

encode Barrio, gen (barrio_cod)
gen zona = .
replace zona = 1 if inlist(Barrio, "Caseros", "Ciudadela", "Saenz Peña")
replace zona = 2 if inlist(Barrio, "Villa Bosch", "Pablo Podestá", "José Ingenieros")
replace zona = 3 if inlist(Barrio, "El Libertador", "L. Hermosa", "Remedios de Escalada")

gen zona2 = .
replace zona2 = 1 if inlist(Barrio, "Caseros", "Ciudadela")
replace zona2 = 2 if zona2==.   // todo lo demás

// Empieza el análisis


corr tratamiento infra_indice
sum infra_indice if tratamiento==1
sum infra_indice if tratamiento==0

corr tratamiento zona2
corr tratamiento tasa_variacion tasa_variacion_prom

sum vulnerabilidad recibe_refuerzo tiene_patio tiene_material tiene_cocina banos_total2 biblioteca cantidad_salas tiene_2_3 tiene_4_5 tiene_multi tiene_temprano matricula_total docentes_total prop_ninas edad_doc antig_doc  aprendizaje cantidad_salas Edad_director Participación_capacitación_docen antig_dir_anios antig_lab_anios dir_lic dir_prof dir_dipl antig_jardin

estpost summarize ///
vulnerabilidad recibe_refuerzo tiene_patio tiene_material tiene_cocina ///
banos_total2 biblioteca cantidad_salas tiene_2_3 tiene_4_5 tiene_multi tiene_temprano ///
matricula_total docentes_total prop_ninas edad_doc antig_doc  aprendizaje ///
Edad_director Participación_capacitación_docen antig_dir_anios antig_lab_anios ///
dir_lic dir_prof dir_dipl antig_jardin

esttab using descriptivos.csv, ///
cells("mean sd min max") ///
replace

estpost summarize ///
vulnerabilidad recibe_refuerzo tiene_patio tiene_material tiene_cocina ///
banos_total2 biblioteca cantidad_salas tiene_2_3 tiene_4_5 tiene_multi tiene_temprano ///
matricula_total docentes_total prop_ninas edad_doc antig_doc  aprendizaje ///
Edad_director Participación_capacitación_docen antig_dir_anios antig_lab_anios ///
dir_lic dir_prof dir_dipl antig_jardin if tratamiento==1

esttab using descriptivos_T.csv, ///
cells("mean sd min max") ///
replace

pwcorr tratamiento vulnerabilidad recibe_refuerzo banos_total2 biblioteca cantidad_salas ///
tiene_2_3 tiene_4_5 tiene_multi tiene_temprano matricula_total docentes_total prop_ninas ///
edad_doc antig_doc aprendizaje Edad_director Participación_capacitación_docen ///
antig_dir_anios antig_lab_anios dir_lic dir_dipl antig_jardin infra_indice ///
matricula_prom docentes_prom, star(0.05)

corr tratamiento vulnerabilidad recibe_refuerzo banos_total2 biblioteca cantidad_salas ///
tiene_2_3 tiene_4_5 tiene_multi tiene_temprano matricula_total docentes_total prop_ninas ///
edad_doc antig_doc aprendizaje Edad_director Participación_capacitación_docen ///
antig_dir_anios antig_lab_anios dir_lic dir_dipl antig_jardin infra_indice ///
matricula_prom docentes_prom

matrix C = r(C)

putexcel set correlaciones.xlsx, replace
putexcel A1 = matrix(C), names


// Correr el do matching exacto

// Correr el do de matching manual

// Matching PSM sin coniderar zona

* guardar ID
gen id = _n

preserve
drop if ID_institución==27

* correr matching
drop _pscore _treated _support _weight _id _n1 _nn _pdif

*Opción 1 (mejor da)
		
psmatch2 tratamiento ///
    matricula_prom  tasa_variacion    ///
 if ID_institución != 27 & (tratamiento==0 | tratamiento==1) & tiene_multi==1, ///
 neighbor(1)  noreplacement 

		

 * ver matches
list id ID_institución _n1 if tratamiento==1

* test
pstest matricula_prom tasa_variacion  , both

* Armo la tabla
preserve

* Quedarse solo con tratadas y controles matcheados
keep if _weight>0 | tratamiento==1

* Crear archivo temporal
tempfile stats
postfile handle str35 variable ///
    mean_control sd_control ///
    mean_tratada sd_tratada ///
    using `stats', replace

* Lista de variables
local vars vulnerabilidad recibe_refuerzo tiene_patio tiene_material tiene_cocina ///
banos_total2 biblioteca cantidad_salas tiene_2_3 tiene_4_5 tiene_multi tiene_temprano ///
matricula_total docentes_total prop_ninas edad_doc antig_doc aprendizaje ///
Edad_director Participación_capacitación_docen antig_dir_anios antig_lab_anios ///
dir_lic dir_prof dir_dipl antig_jardin

* Loop para guardar medias y sd por grupo
foreach v of local vars {
    quietly summarize `v' if tratamiento==0
    local mc = r(mean)
    local sc = r(sd)

    quietly summarize `v' if tratamiento==1
    local mt = r(mean)
    local st = r(sd)

    post handle ("`v'") (`mc') (`sc') (`mt') (`st')
}

postclose handle

* Abrir la base resumen
use `stats', clear

* Exportar a Excel real
export excel using "balance.xlsx", firstrow(variables) replace

restore

* test de blanace T y C

* Opción 2 (algo bien)
psmatch2 tratamiento ///
    vulnerabilidad matricula_prom docentes_prom tiene_multi banos_total2 antig_dir_anios, ///
    neighbor(1) noreplacement

* ver matches
list id ID_institución _n1 if tratamiento==1

* test
pstest vulnerabilidad matricula_prom docentes_prom tiene_multi banos_total2 antig_dir_anios, both

* Opción 3 (no da bien)
psmatch2 tratamiento ///
    recibe_refuerzo matricula_prom docentes_prom tiene_multi banos_total2 antig_dir_anios, ///
    neighbor(1) noreplacement

* ver matches
list id ID_institución _n1 if tratamiento==1

* test
pstest recibe_refuerzo matricula_prom docentes_prom tiene_multi banos_total2 antig_dir_anios, both

* Opción 4
psmatch2 tratamiento ///
    recibe_refuerzo matricula_prom  infra_indicev1 Edad_director, ///
    neighbor(1) noreplacement

* ver matches
list id ID_institución _n1 if tratamiento==1

* test
pstest recibe_refuerzo matricula_prom infra_indicev1 Edad_director, both

* Opción 5 (es el que mejor da)
psmatch2 tratamiento ///
    matricula_prom recibe_refuerzo Edad_director, ///
    neighbor(1) noreplacement
	
* ver matches
list id ID_institución _n1 if tratamiento==1

* test
pstest  matricula_prom recibe_refuerzo Edad_director, both


* Opción 6
psmatch2 tratamiento ///
    matricula_prom recibe_refuerzo Edad_director banos_total2, ///
    neighbor(1) noreplacement
	
* ver matches
list id ID_institución _n1 if tratamiento==1

* test
pstest  matricula_prom recibe_refuerzo Edad_director banos_total2, both

** Excluyo el maternal
preserve
drop if ID_institución==27

* Opción 5 (es el que mejor da)
psmatch2 tratamiento ///
    matricula_prom recibe_refuerzo sala_2 Edad_director, ///
    neighbor(1) noreplacement
	
* ver matches
list id ID_institución _n1 if tratamiento==1

* test
pstest  matricula_prom recibe_refuerzo sala_2 Edad_director, both

psmatch2 tratamiento ///
    matricula_prom recibe_refuerzo  sala_2 , ///
    neighbor(1) noreplacement
	
* ver matches
list id ID_institución _n1 if tratamiento==1

* test
pstest   matricula_prom recibe_refuerzo  Edad_director , both

****
drop _pscore _treated _support _weight _id _n1 _nn _pdif

	

/// VER DE HACER OTROS INDICES

recibe_refuerzo
matricula_total
tiene_multi
tiene_2_3
banos_total2
antig_dir_anios), ///
    nneighbor(1)
	
* ---------------------------------------------------- *
* 2) Matching con la data de salas de 4 y 5 unicamente
* ---------------------------------------------------- *
use "$data_fin/Data_processed.dta", clear 

* 2.1) Entropy balancing
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
di "`variables3'"

levelsof variables7, local(variables7)
di "`variables7'"

levelsof variables14, local(variables14)
di "`variables14'"

levelsof variables23, local(variables23)
di "`variables23'"

levelsof variables29, local(variables29)
di "`variables29'"

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
gen control23 = inlist(ID_institucion, )
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


* 2.2) Matching a nivel de grupos manual

* 2.3) Matching a nivel de individual manual (con y sin reemplazo; priorizando o no vulnerabilidad / zona)

	
