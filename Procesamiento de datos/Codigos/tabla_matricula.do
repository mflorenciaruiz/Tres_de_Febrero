
cd "/Users/florenciaruiz/Library/Mobile Documents/com~apple~CloudDocs/RA Maria/Tres de Febrero/Tres_de_Febrero/Procesamiento de datos/"

use "/Users/florenciaruiz/Library/Mobile Documents/com~apple~CloudDocs/RA Maria/Tres de Febrero/Tres_de_Febrero/Procesamiento de datos/Datos/Intermediate/Salas.dta", clear

* Mergeo para tener la data de quiénes son los tratados
merge m:1 ID_institución using "Datos/Raw/Instituciones.dta"

keep ID_institución Matrícula_total_por_sala T Sala Turno

* Cantidad de chicos por sala y tratamiento
collapse (sum) Matrícula_total_por_sala, by(Sala Turno T)

* collapse (sum) Matrícula_total_por_sala, by(Sala T)

sort Sala Turno T

* Recodeo para hacer el reshape
replace T = "1" if T=="SI"
replace T = "0" if T=="NO"
destring T, replace

keep if Sala == "4" | Sala == "5" // solo para la restriccion por sala

*reshape wide Matrícula_total_por_sala, i(Sala) j(T)
reshape wide Matrícula_total_por_sala, i(Sala Turno) j(T)

rename Matrícula_total_por_sala1 Matricula_tratados
rename Matrícula_total_por_sala0 Matricula_controles

*export excel using "Output/tabla_matricula.xlsx", firstrow(variables) replace

export excel using "Output/tabla_matricula_turnos.xlsx", firstrow(variables) replace
