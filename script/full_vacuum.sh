#!/usr/bin/env bash
#######################################################################################################################################
# Programa .....: full_vacuum_v1.sh
# Autor ........: Cleiton Maia (cleiton.maia@gmail.com)
# Data Criação .: 31/08/2023
# Atualização ..:
# Descrição ....: Executar a rotina de VACUUM FULL nas 20 maiores tabelas do banco de dados, as tabelas são elencadas automaticamente
#######################################################################################################################################

#---[ Environment Variables ]
clear
set +x
source /root/.bashrc
logDirectory="/var/tmp"
logFile=$(basename -s .sh "$0").log
logDate=$(TZ=":America/Fortaleza" date +%d-%m-%Y)
dayWeekName=$(TZ=":America/Fortaleza" date +%a)  # |Seg |Ter |Qua |Qui |Sex |Sab |Dom
totalLines=$(wc -l < "$logDirectory/$logFile")
currentDay=$(date +%e)
lastSun=$(date -d "-$(date +%d) days +1 month -$(date +%w) days" +'%d')
appVersion=2.0.4
appName=$(basename "$0")
export PGPASSWORD=$vDBSenha
export TERM=xterm

#---[ System Function ]
functionBanner() {
  echo   ""
  echo   "╔════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════╗"
  echo   "║                                                                                                                        ║"
  printf "║$(tput bold) %-118s $(tput sgr0)║\n" "$@"
  echo   "║                                                                                                                        ║"
  echo   "╚════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════╝"
  echo ""
}

#---[ Log control and Validations ]
[[ ! -f "$logDirectory/$logFile" ]] && : > "$logDirectory/$logFile"

[[ "$totalLines" -ge 500 ]] && sed -i "$logDirectory/$logFile" -e '1,100d'

#---[ Start Procedure ]
if [ $lastSun -eq $currentDay ]; then
  # Generate List Tables
  psql -h "$vDBHost" -U "$vDBUser"  -d "$vDBNome" -t -A -c "SELECT esquema || '.' || tabela tabela FROM (SELECT tablename AS tabela, schemaname AS esquema, schemaname||'.'||tablename AS esq_tab FROM pg_catalog.pg_tables WHERE schemaname NOT IN ('pg_catalog', 'information_schema', 'pg_toast') ) AS x ORDER BY pg_total_relation_size(esq_tab) DESC LIMIT 20;" > $logDirectory/listtables.dat
  while read idTable; do
    if [ -n "$idTable" ]; then
      clear
      initialTime=$(TZ=":America/Fortaleza" date +%T)
      functionBanner ">>>>> Starting process VACUUM FULL <<<<<" \
                     ""                                         \
                     "Database Name ..: $vDBNome"               \
                     "Table Name .....: $idTable"
      initialTimeSum=$(TZ=":America/Fortaleza" date  +%s) # Captura o primeiro TimeStamp
      sizeBefore=$(psql -h "$vDBHost" -U "$vDBUser"  -d "$vDBNome" -t -c "\dt+ $idTable" | awk '{print $9}')
      psql -h "$vDBHost" -U "$vDBUser"  -d "$vDBNome" -c "VACUUM (FULL, VERBOSE, ANALYZE, TRUNCATE) $idTable ; "
      sizeAfter=$(psql -h "$vDBHost" -U "$vDBUser"  -d "$vDBNome" -t -c "\dt+ $idTable" | awk '{print $9}')
      finishTime=$(TZ=":America/Fortaleza" date +%T)
      finalTimeSum=$(TZ=":America/Fortaleza" date  +%s) # Captura o segundo TimeStamp
      totalRecordSum=$(( finalTimeSum - initialTimeSum )) # Diferenca entre os TimeStamps
      totalTime=$(date -d @$totalRecordSum +%H:%M:%S)
      echo "Day: $dayWeekName [$currentDay] - Table: $idTable - Size: $sizeBefore-$sizeAfter MB - Date: $logDate Started: $initialTime Finished: $finishTime Total Time: $totalTime" >> "$logDirectory/$logFile"
    fi
  done < $logDirectory/listtables.dat
fi
