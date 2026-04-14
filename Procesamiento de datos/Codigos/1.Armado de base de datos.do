** Armado de base de datos

global main "/Users/florenciaruiz/Library/Mobile Documents/com~apple~CloudDocs/RA Maria/Tres de Febrero/Procesamiento de datos"
global data_folder "$main/Datos"
global data_raw "$data_folder/Raw"
global data_int "$data_folder/Intermediate"
global data_fin "$data_folder/Final"

import excel "$data_raw/Base_instituciones_3Feb_editadoVA.xlsx", sheet("salas_dta") firstrow clear

preserve

keep if Sala == "4" | Sala == "5"
 
*keep if Año==2023 | Año==2025
collapse (sum) Matrícula_total_por_sala, by (ID_institución Año)
sort ID_institución Año

* Crear variables por año
gen m2023 = Matrícula_total_por_sala if Año==2023
gen m2024 = Matrícula_total_por_sala if Año==2024
gen m2025 = Matrícula_total_por_sala if Año==2025

* Llevar esos valores a nivel institución
by ID_institución: egen base_2023 = max(m2023)
by ID_institución: egen base_2024 = max(m2024)
by ID_institución: egen base_2025 = max(m2025)

* Calcular tasa de variación
gen tasa_variacion = (base_2025 - base_2023) / base_2023

*keep ID_institución tasa_variacion
*duplicates drop
*save "C:\Users\vicky\OneDrive\Documentos\Tres de Febrero\Procesamiento\Datos\Var_matricula.dta"
*restore

* Alternativa de tasa de variación

* 1) Sumar matrícula por institución y año
bysort ID_institución Año: egen matricula_inst = total(Matrícula_total_por_sala)

* 2) Dejar una sola fila por institución-año para evitar duplicados
bysort ID_institución Año: keep if _n==1

* Promedio pretratamiento
gen base_pre = (base_2023 + base_2024)/2

* Variación respecto de 2025
gen tasa_variacion_prom = (base_2025 - base_pre) / base_pre

keep ID_institución tasa_variacion_prom tasa_variacion
duplicates drop
save "$data_int/Var_matricula3.dta", replace

restore

* Nos quedamos con datos de 2025
keep if Año==2025
keep if Sala == "4" | Sala == "5"
drop NombredelJardín Fecha_de_nacimiento_docente

encode Turno, gen(turno_cod)

replace _niñas = subinstr(_niñas, ",", ".", .)
replace _niñas = "" if _niñas=="-"
destring _niñas, replace

replace Edad_docente_referencia = "" if Edad_docente_referencia=="-"
destring Edad_docente_referencia, replace

replace Antigüedad_docente= "" if Antigüedad_docente=="-"
destring Antigüedad_docente, replace
rename Antigüedad_docente ant_docente

replace Medidadeaprendizajes = "" if Medidadeaprendizajes=="-"
replace Medidadeaprendizajes = subinstr(Medidadeaprendizajes, "%", "", .)
replace Medidadeaprendizajes = trim(Medidadeaprendizajes)
replace Medidadeaprendizajes = subinstr(Medidadeaprendizajes, ",", ".", .)
destring Medidadeaprendizajes, replace

** Variables para collapsar
gen peso = Matrícula_total_por_sala
gen docentes_total = Cant_docentes_sala

rename ID_institución id_inst
rename Matrícula_total_por_sala matricula
rename Formación_docente formacion_doc
rename Edad_docente_referencia edad_doc
rename Medidadeaprendizajes aprendizaje

egen sala_id = group(Sala turno_cod)
bysort id_inst Año sala_id: gen tag = (_n==1)

*gen d_multi = strpos(Sala, "Multi")>0
*gen d_temprano = inlist(Sala, "Lactantes", "Deambuladores", "Deambuladores y 2")
*gen d_2_3 = inlist(Sala, "2", "3")
gen d_4_5 = inlist(Sala, "4", "5") | strpos(Sala, "4 y 5")>0
tab d_4_5

* Turnos
gen tm = (Turno=="TM")
gen tt = (Turno=="TT")
*gen je = (Turno=="JORNADA EXTENDIDA")

bysort id_inst: egen any_tm = max(tm)
bysort id_inst: egen any_tt = max(tt)
*bysort ID_institución: egen any_je = max(je)

* Guardo la data de covariables a nivel de sala
save "$data_int/covariables_sala.dta", replace

* Colapso a nivel de institución
collapse ///
(sum) matricula_total = matricula ///
(sum) docentes_total = docentes_total ///
(mean) prop_ninas = _niñas ///
(mean) edad_doc = edad_doc ///
(mean) antig_doc = ant_docente ///
(mean) formacion_doc = formacion_doc ///
(mean) aprendizaje = aprendizaje ///
(sum) cantidad_salas = tag ///
(max) any_tm  ///
(max) any_tt ///
[aw=peso], by(id_inst Año)

rename id_inst ID_institución

merge 1:1 ID_institución using "$data_raw/Instituciones.dta"

* Eliminamos las que no matchean (las que no tienen salas de 4 o 5)
drop if _merge == 2
drop _merge

* Convertimos a variables numéricas
gen vulnerabilidad = (Vulnerabilidad_barrio == "SI")
gen recibe_refuerzo = (Recibe_ref_alim == "SI")
gen tiene_cocina = (Cocina_comedor == "SI")
gen tiene_patio = (Patio == "SI")
gen tiene_material = (Material_didáctico == "SI")
gen cap_dir = (Participación_capacitación_direc == "SI")

gen banos_ninos = .
replace banos_ninos = real(regexs(1)) if regexm(Nro_baños, "([0-9]+) baños de niños")

gen banos_adultos = .
replace banos_adultos = real(regexs(1)) if regexm(Nro_baños, "([0-9]+) de adultos")

gen banos_total2 = banos_ninos + banos_adultos
replace banos_total2 = banos_adultos if banos_ninos==. & banos_adultos!=.
replace banos_total2 = banos_ninos if banos_ninos!=. & banos_adultos==.

gen biblioteca = 0
replace biblioteca = 1 if Biblioteca=="Tiene biblioteca" | Biblioteca=="Tiene biblioteca en el SUM" 
drop Biblioteca

gen antig_dir_anios = .
* casos mixtos
replace antig_dir_anios = real(regexs(1)) + real(regexs(2))/12 ///
if regexm(Antigüedad_director, "([0-9]+) año[s]?.*?([0-9]+) mes")
* años
replace antig_dir_anios = real(regexs(1)) ///
if regexm(Antigüedad_director, "([0-9]+) año[s]?") ///
& strpos(Antigüedad_director, "mes")==0
* meses → pasar a años
replace antig_dir_anios = real(regexs(1))/12 ///
if regexm(Antigüedad_director, "([0-9]+) mes") & ///
strpos(Antigüedad_director, "año")==0

gen antig_lab_anios = .
* casos mixtos
replace antig_lab_anios = real(regexs(1)) + real(regexs(2))/12 ///
if regexm(Antigüedad_laboral, "([0-9]+) año[s]?.*?([0-9]+) mes")
* años
replace antig_lab_anios = real(regexs(1)) ///
if regexm(Antigüedad_laboral, "([0-9]+) año[s]?") ///
& strpos(Antigüedad_laboral, "mes")==0
* meses → pasar a años
replace antig_lab_anios = real(regexs(1))/12 ///
if regexm(Antigüedad_laboral, "([0-9]+) mes") & ///
strpos(Antigüedad_laboral, "año")==0

gen dir_lic = strpos(lower(Formación_director), "lic") > 0
gen dir_prof = strpos(lower(Formación_director), "profesor") > 0
gen dir_dipl = strpos(lower(Formación_director), "diplom") > 0

gen antig_jardin = Año_inaugaración
replace antig_jardin = 2024 - Año_inaugaración

gen tratamiento = (T == "SI")

drop Modalidad T Vulnerabilidad_barrio Recibe_ref_alim Año_inaugaración Tipo_gestión Cocina_comedor Nro_baños Antigüedad_director Antigüedad_laboral Material_didáctico Patio  Participación_capacitación_direc

* Turnos
*gen tm = (Turno=="TM")
*gen tt = (Turno=="TT")
*gen je = (Turno=="JORNADA EXTENDIDA")

*bysort ID_institución: egen any_tm = max(tm)
*bysort ID_institución: egen any_tt = max(tt)
*bysort ID_institución: egen any_je = max(je)

gen tipo_turno = ""
replace tipo_turno = "Solo mañana" if any_tm==1 & any_tt==0
replace tipo_turno = "Solo tarde" if any_tm==0 & any_tt==1
replace tipo_turno = "Mañana y tarde" if any_tm==1 & any_tt==1

save "$data_int/Salas_inst2.dta", replace

** Agrego la información nueva (inasistencias, auh, nivel educativo padres) 

import excel "$data_raw/Pedido de información abril 2026.xlsx",  sheet("data_stata") firstrow clear

keep if Sala == "4" | Sala == "5"
drop NombredelJardín

* % que recibe AUH
gen auh = _hogares_AUH 
replace auh = subinstr(auh, ",", ".", .)
replace auh = subinstr(auh, "%", "", .)
replace auh = trim(auh)
destring auh, replace
replace auh = auh*100 if auh<=1
drop _hogares_AUH
* hay dos auh con 1.05, por ahora le pongo 100
replace auh = 100 if auh ==1.05

* % inasistencias
gen inasistencia = Inasistencia*100
drop Inasistencia

* Maximo nivel educativo de los padres
tab Max_niv_ed
replace Max_niv_ed = "" if Max_niv_ed=="-"
label define max_niv_ed 1 "Secundario incompleto" 2 "Secundario Completo" 3 "Terciario Completo" 4 "Universitario Completo"
encode Max_niv_ed, gen(max_niv_ed) label(max_niv_ed)
tab max_niv_ed
label list max_niv_ed
drop Max_niv_ed

* Guardo la data
save "$data_int/covariables_extra.dta", replace

* Mergeo con la matricula
import excel "$data_raw/Base_instituciones_3Feb_editadoVA.xlsx", sheet("salas_dta") firstrow clear
keep if Sala == "4" | Sala == "5"
keep ID_institución Año Sala Turno Matrícula_total_por_sala

merge 1:1 ID_institución Año Sala Turno using "$data_int/covariables_extra.dta", nogen

* Genero promedios por institucion
preserve
tempfile promedios_inst
collapse ///
(mean) inasistencia_prom_años = inasistencia ///
(mean) auh_prom_años = auh ///
(max) max_niv_ed_años = max_niv_ed ///
[aw=Matrícula_total_por_sala], by(ID_institución)
save `promedios_inst'
restore

* Colapso a nivel de institución-año
collapse ///
(mean) inasistencia ///
(mean) auh ///
(max) max_niv_ed ///
[aw=Matrícula_total_por_sala], by(ID_institución Año)

merge m:1 ID_institución using `promedios_inst', nogen

* Paso a wide
reshape wide inasistencia auh max_niv_ed, i(ID_institución) j(Año)

* Borro las variables de educacion 2023, 2024 y el maximo de los 3 años porque no hay data para los dos primeros años
drop max_niv_ed2023 max_niv_ed2024 max_niv_ed_años

* Uno con la data de salas e instituciones
merge 1:1 ID_institución using "$data_int/Salas_inst2.dta"
* Las que no mergean son instituciones que no tienen sala de 4 o 5 en 2025, las borro
drop if _merge ==1
drop _merge

tab max_niv_ed2025 // no hay mucha variabilidad, seria bueno tener %
sum auh_prom_años if tratamiento==1 // no hay data de auh para los tratados

* Mergeo para tener la tasa de variación
merge 1:1 ID_institución using "$data_int/Var_matricula2"
drop if _merge == 2 // jardines sin salas de 4 o 5 en 2025
drop _merge

rename ID_institución ID_institucion

tab tratamiento vulnerabilidad
tab tratamiento recibe_refuerzo

gen banos_prom=banos_total2/matricula_total
egen z_patio = std(tiene_patio)
egen z_biblio = std(biblioteca)
egen z_banos = std(banos_total2)
egen z_banos_prom = std(banos_prom)
egen infra_indice = rowmean(z_patio z_biblio z_banos)
egen infra_indicev1 = rowmean(z_patio z_biblio z_banos_prom)

save "$data_fin/Data_processed.dta", replace
