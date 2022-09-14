@for /F "tokens=1-3 delims=/- " %%A in ('date /T') do @set datevar=%%C%%B%%A
@for /F "tokens=1-3 delims=:-. " %%A in ('echo %time%') do @set timevar=%%A%%B%%C&set hour=%%A
@if %hour% LSS 10 set timevar=0%timevar%
@set filename=%datevar%_%timevar%_%1.etl
wpr -stop WPRResults\%filename%
