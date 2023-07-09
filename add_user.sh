#!/bin/bash


# Explicit argument renaming feature for better visibility and unsderstanding
function wrap_arguments (){
    while (( "${#}" )); do              # as long as there are arguments
        if [[ "${1}" == "--"* ]]; then  # if it starts with double hyphen
            option="${1/--/}"           # expand them without it and assign the value to a variable
            shift
        fi
        declare -ng ${option}=$1        # namereference (-n) the argument with his option'name and make it global (-g)
        shift
    done
}

# Exception and error handling
function check_proccess (){

    wrap_arguments "${@}"               # with our wrapper and a good naming policy/convention, we can now easily browse the code without additional comments

    declare success_body unsuccess_body check_mark; declare -a success_attr unsuccess_attr; declare -A check_form; check_mark=$(printf "%b" "\342\234\224")
    success_body=$(printf "%s %s" "${check_mark}" "${fail_layout[success]}"); success_attr=( "${format[bold]}" "${foreground[green]}" ); check_form=( [o_newline]=1 [leading_space]=0 [tab]=1 [padding]=0 [trailing_space]=3  [c_newline]=2)
    unsuccess_body="$(printf "%b It seems that something went wrong as the installation/configuration process did not complete !!\n\tError(s) stage: \"%s (%s)\"\n\tSee \`tail -v %s\`\n\n" "\u274c" "${fail_layout[funcname]}" "${fail_layout[obj]}" "${main_error}")"
    unsuccess_attr=( "${format[bold]}" "${foreground[red]}" )

    if [[ "${status}" -eq 0 ]]; then
        display --body success_body --attributes success_attr --formats check_form
	else
        display --body unsuccess_body --attributes unsuccess_attr --formats check_form
        exit "${status}"
    fi
}

# Text renderer with custom attributes (format and color)
function display (){

    wrap_arguments "${@}"

    declare cleat open close body_slot s_space e_space

    for format in "${!formats[@]}"
    do
        case "${format}" in
        *_space)
            case "${format}" in
            leading_space)
                for i in $(seq ${formats[${format}]})
                do
                    s_space="${s_space} "
                done
                ;;
            trailing_space)
                for i in $(seq ${formats[${format}]})
                do
                    e_space="${e_space} "
                done
                ;;
            esac
            for format in "${!formats[@]}"
            do
                case "${format}" in
                padding)
                    body_slot="${s_space}%${formats[${format}]}s${e_space}"
                    ;;
                esac
            done
            ;;
        tab)
            for i in $(seq ${formats[${format}]})
            do
                cleat="${cleat}\t"
            done
            ;;
        o_newline)
            for i in $(seq ${formats[${format}]})
            do
                open="${open}\n"
            done
            ;;
        c_newline)
            for i in $(seq ${formats[${format}]})
            do
                close="${close}\n"
            done
            ;;
        esac
    done

    printf -v attribute "${attributes[*]}"
	start_spotlight="\e[${attribute// /;}m"
	end_spotlight="\e[0m"          # removes all attributes (format and color)
	printf "%b%b%b${body_slot}%b%b" "${open}" "${cleat}" "${start_spotlight}" "${body}" "${end_spotlight}" "${close}"

}

# intermediary feature to display a given quote
function tag (){

    wrap_arguments "${@}"

    for i in $(seq ${recurrence})
    do
        display --body tag_body --attributes tag_attr --formats tag_form
    done

}

# visual to delimits the jobs
function delimiter (){

    wrap_arguments "${@}"

    declare marker starting_text expand_anchor reps; declare -a delimiter_attr; declare -A body_form marker_form
    marker="=" expand_anchor="${anchor#*_} ${anchor%%_*}ing ..." starting_text="${expand_anchor^}" reps=35
    body_form=( [o_newline]=0 [leading_space]=3 [tab]=0 [padding]=-40 [trailing_space]=3  [c_newline]=0); marker_form=( [o_newline]=0 [leading_space]=0 [tab]=0 [padding]=0 [trailing_space]=0  [c_newline]=0)
    delimiter_attr=( "${format[bold]}" "${foreground[green]}" )

    printf "\n"
    tag --recurrence reps --tag_body marker --tag_attr delimiter_attr --tag_form marker_form
    display --body starting_text --attributes delimiter_attr --formats body_form
    tag --recurrence reps --tag_body marker --tag_attr delimiter_attr --tag_form marker_form
    printf "\n"

}

# test the password against the rule
function audit_passwd_compliance (){
    wrap_arguments "${@}"

    case "${control}" in
    Min*)
        if [[ "${#value}" -lt "${standard}" ]]; then
            failed_rule+=( "${control}" )
        fi
        ;;
    Strong*)
        while read output_check
        do
            if [[ "${output_check}" != "OK" ]]; then
                failed_rule+=( "${control}" )
            fi
        done < <(awk -F': ' '{ print $NF}' <<< "$(${standard} <<< ${value})")
        ;;
    *)
        if ! [[ "${value}" =~ ${standard} ]]; then
            failed_rule+=( "${control}" )
        fi
        ;;
    esac
}

# check if user already exist in the system
function check_duplicate (){

    wrap_arguments "${@}"

    declare funcname exit; funcname="${FUNCNAME[0]}"; declare -A fail_output; fail_output=( [success]="" ["funcname"]="${funcname}" ["obj"]="\`${user}\` user already exists" )
    delimiter --anchor funcname
    while read line; do
        if [[ "${line}" =~ ^${user}$ ]]; then
            exit=1
        fi
    done < <(getent passwd | awk -F':' '{print $1}')
	check_proccess --status exit --fail_layout fail_output

}

# key function that displays the requirement, calls password auditing function and adds the user to the system
function process_user_and_password (){

    wrap_arguments "${@}"

    declare funcname initiate_passwd_confirmation exit; declare -A warning_attr fail_output; funcname="${FUNCNAME[0]}" initiate_passwd_confirmation=true
    warning_attr=( [o_newline]=0 [leading_space]=3 [tab]=1 [padding]=-35 [trailing_space]=3 [c_newline]=1 )
    fail_output=( [success]="user \`${user}\` has been successfully added to the wheel group" ["funcname"]="${funcname}" ["obj"]="Failed to add user \`${user}\` to the system" )

    case "${launch}" in
    true)
        delimiter --anchor funcname
        printf "\n%s\n\n" "The password must be compliant with the following requirement:"
        initiate=false
        ;;
    *)
        printf "\n%s\n\n" "The password is not compliant with the red highlighted requirement(s):"
        ;;
    esac

    for rule in "${!rules[@]}"; do
        if [[ "${failed_rule[@]}" =~ ${rule} ]]; then
            display --body rule --attributes warning --formats warning_attr         # if rule in failed array, highlight it in red
        else
            display --body rule --attributes info --formats warning_attr            # else format it as informationnal
        fi
    done

    failed_rule=()

    printf "\n"
    IFS= read -srep "Enter password for user \`${user}\`: $(echo $'\n> ')" password
    printf "\n"

    for rule in "${!rules[@]}"; do
        requirement="${rules[${rule}]}"
        audit_passwd_compliance --control rule --value password --standard requirement
    done

    if [[ "${#failed_rule}" -eq 0 ]]; then
        printf "\n"
        while [[ "${confirmed_passwd}" != "${password}" ]] ; do
            if "${initiate_passwd_confirmation}"; then
                IFS= read -srep "Retype password for user \`${user}\`: $(echo $'\n> ')" confirmed_passwd
                initiate_passwd_confirmation=false
            else
                printf "\n\n"
                IFS= read -srep "Sorry, passwords don't match. Retype password for user \`${user}\`: $(echo $'\n> ')" confirmed_passwd
            fi
        done
        printf "\n"
        useradd -m "${user}" 2>>"${main_error}"; exit="${?}"
        # encrypt the password with SHA512 and add the user to the wheel group to grant privileges
        if [[ "${exit}" -eq 0 ]]; then printf "%s:%s\n" "${user}" "${password}" 2>>"${main_error}" | chpasswd --crypt-method SHA512 2>>"${main_error}"; exit=$(( "${PIPESTATUS[0]} + ${PIPESTATUS[1]}" )); fi
        if [[ "${exit}" -eq 0 ]]; then usermod -aG wheel "${user}" 2>>"${main_error}"; exit="${?}"; fi

        check_proccess --status exit --fail_layout fail_output
    fi

}

function main (){

    if [[ "$(id -u)" -eq 0 ]]; then         # run script with sudo privilege

        declare initiate username main_error; declare -a failed_rule info warning; declare -A convention_rule format foreground background

        format=( [bold]="1" [dim]="2" [underlined]="4" [blink]="5" [reverse]="7" [hidden]="8" )
        foreground=( [default]="39" [black]="30" [red]="31" [green]="32" [yellow]="33" [blue]="34" [magenta]="35" [cyan]="36" [light gray]="37" [dark gray]="90" [light red]="91" [light green]="92" [light yellow]="93" [light blue]="94" [light magenta]="95" [light cyan]="96" [white]="97" )
        background=( [default]="49" [black]="40" [red]="41" [green]="42" [yellow]="43" [blue]="44" [magenta]="45" [cyan]="46" [light gray]="47" [dark gray]="100" [light red]="101" [light green]="102" [light yellow]="103" [light blue]="104" [light magenta]="105" [light cyan]="106" [white]="107" )

        initiate=true main_error="/tmp/main.error"; info=( "${format[bold]}" "${foreground[yellow]}" ); warning=( "${format[bold]}" "${format[blink]}" "${foreground[white]}" "${background[red]}" )
        convention_rule=( ["Strong password"]="cracklib-check" ["Minimum of 8 characters"]="8" ["At least 1 upper case"]="[[:upper:]]" ["At least 1 lower case"]="[[:lower:]]" ["At least 1 digit"]="[[:digit:]]" ["At least 1 special character"]="[[:blank:]]|[^[:alnum:]]" )

        printf "\n"
        while ! [[ "${username}" ]]; do printf "\n"; read -p "Enter name for new user : " username; done

        check_duplicate --user username
        printf "\n"

        while [[ "${#failed_rule}" -gt "0" ]] || "${initiate}" ; do
            process_user_and_password --launch initiate --rules convention_rule --user username
        done
    else
            printf "\n !!! Privileges are required to run this script.\n\n"
            exit 1
	fi

}

# run the main function only if not sourced/imported
if [[ ${BASH_SOURCE[0]} == ${0} ]]; then
	main
fi
