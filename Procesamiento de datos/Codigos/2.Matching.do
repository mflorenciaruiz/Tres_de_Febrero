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
	