#!/bin/sh -f

# --------- License Info ---------
# Copyright 2013 Emind Systems Ltd - htttp://www.emind.co
# This file is part of Emind Systems DevOps Tool set.
# Emind Systems DevOps Tool set is free software: you can redistribute it and/or modify it under the terms of the GNU General Public License as published by the Free Software Foundation, either version 3 of the License, or (at your option) any later version.
# Emind Systems DevOps Tool set is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU General Public License for more details.
# You should have received a copy of the GNU General Public License along with Emind Systems DevOps Tool set. If not, see http://www.gnu.org/licenses/.

input_param=$*

# Configurations
base_dir=/usr/local/emind/snmp-subagent
cfg_file=${base_dir}/snmp_subagent.cfg

function init ()
{
    write_log "==== Generic SubAgent Started ===="
    write_log "input_param=${input_param}"	
}

function find_oid ()
{    
    line_num=""
    line_num=$(grep -n "${req_oid}:" ${cfg_file} | cut -f1 -d:)
    
    if [ "${line_num}" = "" ]; then
        write_log "find_oid oid: ${req_oid} is not found in ${cfg_file}"
	return
    else
	write_log "find_oid oid: ${req_oid} found in:${cfg_file} line:${line_num}"
    fi
    
	if [ "${mode}" == "GETNEXT" ]; then
	
		# check if snmpd was called by snmpgetnext command
        # set total_lines to check if we get the last oid
        total_lines=$(wc -l ${cfg_file} | cut -f1 -d" ")

        # check if we get the last oid, else getting the next oid
        if [ ${line_num} -lt ${total_lines} ]; then
		line_num=$(( ${line_num} + 1 ))
	else [ ${line_num} -eq ${total_lines} ];
		line_num=0
	fi
    fi
}

function parse_line ()
{
	line=$1
    file=$2
	line_data=$(tail -n +${line} ${file} | head -1)
	
	oid=$(echo ${line_data} | cut -f1 -d:)
	write_log "parse_line oid=${oid}"
	
	type=$(echo ${line_data} | cut -f2 -d:)
	write_log "parse_line type=${type}"
	
	cmd=$(echo ${line_data} | cut -f3 -d:)
	write_log "parse_line cmd=${cmd}"
}

function write_log()
{
	logger -t snmp-subsgent[$$] -- "$*"
}

function exec_cmd ()
{
	command=$*
	write_log "Exceuting ${cmd}"
	data=$(${cmd})
	#data=`exec ${cmd}`
	err_code=$?
}

function on_error ()
{
	my_oid=$1
	error_code=$2
	error_desc=$3
	write_log "error_code=${error_code} error_desc=${error_desc}"
	# see spec for error handling, for returning no_such by master
	# return_results_to_master ${my_oid} STRING ${error_code}
	finish
}

function return_results_to_master ()
{
        my_oid=$1
        my_type=$2
        my_value=$3
        
        write_log "--- RETRUN RESULTS ---"
        write_log "oid=${my_oid}"
        write_log "type=${my_type}"
        write_log "value=${my_value}"

        echo ${my_oid}
        echo ${my_type}
        echo ${my_value}
}

function finish ()
{
        write_log "==== Generic SubAgent Ended ===="
        exit 0
}

mode=""
req_oid=""

init
while getopts g:s:n: OPTNAME
do	
	case "$OPTNAME" in
	g)
		mode=GET
		req_oid="$OPTARG"
		;;
	s)	
		mode=SET
		req_oid="$OPTARG"
	;;
	n)
		mode=GETNEXT
		req_oid="$OPTARG"
	;;
	esac
done

if [ "${mode}" = "" ] || [ "${req_oid}" = "" ]; then
	on_error 0 -2 "Bad Input"
fi

write_log "mode=${mode} req_oid=${req_oid}"

find_oid									#sets: line_num 
if [ "${line_num}" = 0 ]; then
	on_error ${req_oid} -2 "No NEXT oid found"
elif [ "${line_num}" != "" ]; then
	 parse_line ${line_num} ${cfg_file}		#sets oid, type, cmd
else
	on_error ${req_oid} -1 "OID Not Found"      
fi

exec_cmd ${cmd}   					        #sets: err_code, data
if [ ${err_code} ]; then
	return_results_to_master ${oid} ${type} ${data}
else
	on_error ${oid} ${err_code} "${cmd} failed"
fi

finish
