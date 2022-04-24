#!/bin/bash

# What's left to do?
# 1. Refactor the code to create less tmp files and be more efficient overall (and also faster)
# 2. Make menu with options to either
#    2.1 (n) Get next chapter 
#    2.2 (p) Get previous chapter
#    2.3 (s) Select chapter
# 3. Search the law to upddate disclaimer
# 4. Check if the script actually needs all of the ${dependencies}
# 5. Work on a better incrementing algorithm for next chapter

############### FINISH PRINT_OPTIONS FUNCTION ###############

########
# INFO #
########

version="0.4b"

tmp_dir="$HOME/.cache/manga-cli-br/tmp"
img_dir="${tmp_dir}/imgs"
pdf_dir="$HOME/.cache/manga-cli-br/pdf"

dependencies=("ls" "cat" "curl" "awk" "sed" "tr" "du" "rm" "mkdir" "git" "diff" "patch" "zathura" "img2pdf")


####################
# FORMAT FUNCTIONS #
####################

format_search() {
    formatted_search="$(printf "%s" "${manga_to_search}" | tr " -" "+" | sed 's/^.//')"
}

####################
# SCRAPE FUNCTIONS #
####################

get_titles_and_links() {
    not_found="$(curl --silent "https://muitomanga.com/buscar?q=${formatted_search}" | grep -c "Nenhum resultado encontrado")"

    if [ "${not_found}" -ge 1 ]; then
        echo "Mangá não foi encontrado"
        exit 1
    else
        curl --silent "https://muitomanga.com/buscar?q=${formatted_search}" | grep "</a></h3>" | awk -F'<a |</a>' '{print $2}' > "${tmp_dir}/titles-and-links.txt"
        awk -F'/|"' '{print $4}' "${tmp_dir}/titles-and-links.txt" > "${tmp_dir}/links.txt" &
        awk -F'>' '{print $2}' "${tmp_dir}/titles-and-links.txt" > "${tmp_dir}/titles.txt"
    fi

    titles_amount=$(wc -l "${tmp_dir}/titles.txt" | awk '{print $1}')
}

get_chapters() {
    curl --silent "https://muitomanga.com/manga/${manga_link}" | grep "class=\"single-chapter\" data-id-cap=\"" | awk -F'"' '{print $4}' > "${tmp_dir}/chapters.txt"
    echo -n "[$(tail -n 1 "${tmp_dir}/chapters.txt")~$(head -n 1 "${tmp_dir}/chapters.txt")]"

    chapters_min=$(tail -n 1 "${tmp_dir}/chapters.txt")
    chapters_max=$(head -n 1 "${tmp_dir}/chapters.txt")
}

get_imgs() {
    curl --silent "https://muitomanga.com/ler/${manga_link}/capitulo-${chosen_chapter}" | grep "imagens_cap" > "${tmp_dir}/imgs.txt"
    curl --silent "https://muitomanga.com/ler/${manga_link}/capitulo-${chosen_chapter}" | grep "value=\"0\"" | awk -F'1 / |<' '{print $3}' >> "${tmp_dir}/imgs.txt"
    imgs_max=$(tail -n 1 "${tmp_dir}/imgs.txt")

    i=2
    while [ $((i)) -lt $((imgs_max * 2 + 1)) ]; do
        awk -F'"' "{print \$$((i))}" "${tmp_dir}/imgs.txt" >> "${tmp_dir}/imgs2.txt"
        i=$((i+2))
    done
    
    sed 's/\\//g' "${tmp_dir}/imgs2.txt" | grep '\S' > "${tmp_dir}/imgs.txt"
    mapfile -t img_urls < <(cat "${tmp_dir}/imgs.txt")

    mkdir "${img_dir}"
    i=0
    for image in "${img_urls[@]}"; do
        i=$((i+1))
        curl --silent --create-dirs --header 'Referer: https://muitomanga.com/' --output "${img_dir}/${i}.jpg" "${image}" &
    done

    i=0
    for image in "${img_urls[@]}"; do
        i=$((i+1))
        echo -n "${img_dir}/${i}.jpg " >> "${tmp_dir}/imgs_addresses.txt"
    done

    wait
}

get_pdf() {
    echo "Convertendo imagens em PDF..."
    
    if ! test -d "${pdf_dir}"; then
        mkdir "${pdf_dir}"
    fi

    img2pdf $(cat "${tmp_dir}/imgs_addresses.txt") --output "${pdf_dir}/capitulo_${chosen_chapter}.pdf"
    rm -r "${img_dir}"
    clear
}

###################
# PRINT FUNCTIONS #
###################

print_help() {
    while IFS= read -r line; do
        printf "%s\n" "${line}"
    done <<-EOF
    
                                                   _ _        _          
                                                  | (_)      | |         
     _ __ ___   __ _ _ __   __ _  __ _         ___| |_       | |__  _ __ 
    | '_ ' _ \ / _' | '_ \ / _' |/ _' | ____  / __| | | ____ | '_ \| '__|
    | | | | | | (_| | | | | (_| | (_| | |__| | (__| | | |__| | |_) | |   
    |_| |_| |_|\__._|_| |_|\__. |\__._|       \___|_|_|      |_.__/|_|   
                            __/ |                                       
                           |___/                           [Versão: ${version}]

    Script em Bash para ler mangá usando seu terminal!

    COMO USAR: ${0} [Opção]
    OPÇÕES:
    -h ou --help: mostra esta tela
    -v ou --version: mostra a versão do script
    -d ou --debug: não exclui os arquivos temporários gerados pelo script

    COMANDOS IMPORTANTES DO LEITOR DE PDF:
    +: aumenta o zoom
    -: diminui o zoom
    q: sair do leitor

EOF
}

print_options() {
    clear
    echo "[Capítulo ${chosen_chapter} de ${chapters_max}] ${manga_title}"
    echo "[n] - próximo capítulo"
    echo "[p] - capítulo anterior"
    echo "[s] - selecionar capítulo"
    echo "[a] - buscar outro mangá"
    echo "[q] - sair"

    echo -n "Escolha uma opção: "
    read -r chosen_option

    case "${chosen_option}" in
        n)
            chosen_chapter=$((chosen_chapter+1))
            
            if [ ${chosen_chapter} -gt ${chapters_max} ]; then
                echo "Capítulo ainda não está no site!"
                print_options
            fi

            while ! [[ "$(grep -o -x "${chosen_chapter}" "${tmp_dir}/chapters.txt")" ]]; do
                if [ ${chosen_chapter} -gt ${chapters_max} ]; then
                    echo "Capítulo ainda não está no site!"
                    print_options    
                fi
                chosen_chapter=$((chosen_chapter+1))
            done

            clear
            echo "Capítulo escolhido: ${chosen_chapter}"
            echo "Baixando capítulo..."

            remove_img_files
            get_imgs
            get_pdf
            open_pdf
            print_options
        ;;
        p)
            chosen_chapter=$((chosen_chapter-1))

            if [ ${chosen_chapter} -lt ${chapters_min} ]; then
                echo "Capítulo não existe!"
                print_options
            fi

            while ! [[ "$(grep -o -x "${chosen_chapter}" "${tmp_dir}/chapters.txt")" ]]; do
                echo "${chosen_chapter}"
                if [ ${chosen_chapter} -lt ${chapters_min} ]; then
                    echo "Capítulo não existe!"
                    print_options
                fi
                chosen_chapter=$((chosen_chapter-1))
            done

            clear
            echo "Capítulo escolhido: ${chosen_chapter}"
            echo "Baixando capítulo..."

            remove_img_files
            get_imgs
            get_pdf
            open_pdf
            print_options
        ;;
        s)
            choose_chapter

            remove_img_files
            get_imgs
            get_pdf
            open_pdf
            print_options
        ;;
        a)
            formatted_search=
            not_found=
            titles_amount=
            chapters_max=
            imgs_max=
            manga_to_search=
            chosen_manga=
            manga_title=
            manga_link=
            chosen_chapter=
            clear
            main
        ;;
        q)
            clear
        ;;
        *)
            clear
            echo "Opção inválida"
            print_options
        ;;
    esac
   
}

print_mangas() {
    i=1
    while read -r line; do
        echo "[${i}] - ${line}"
        i=$((i+1))
    done <"${tmp_dir}/titles.txt"
}

#############
# GET INPUT #
#############

search_input() {
    echo -n "Qual mangá você quer ler? "
    read -r manga_to_search
    echo "Buscando mangá..."
}

choose_manga() {
    echo -n "Escolha um mangá: "
    read -r chosen_manga
    
    while [ $((chosen_manga)) -lt 1 ] || [ $((chosen_manga)) -gt $((titles_amount)) ]; do
        echo "Número fora do escopo" 
        echo -n "Escolha um mangá: "
        read -r chosen_manga
    done

    echo "Mangá escolhido: $(sed -n "${chosen_manga}p" "${tmp_dir}/titles.txt")"
    manga_title=$(sed -n "${chosen_manga}p" "${tmp_dir}/titles.txt")
    manga_link=$(sed -n "$((chosen_manga))p" "${tmp_dir}/links.txt")
}

choose_chapter() {
    echo -n "Escolha um capítulo "
    get_chapters
    echo -n ": "
    read -r chosen_chapter

    while ! [[ "$(grep -o -x "${chosen_chapter}" "${tmp_dir}/chapters.txt")" ]]; do
        echo "Número fora do escopo ou capítulo não existe"
        echo -n "Escolha um capítulo: "
        read -r chosen_chapter
    done

    clear
    echo "Capítulo escolhido: ${chosen_chapter}"
    echo "Baixando capítulo..."
}

###################
# OTHER FUNCTIONS #
###################

check_dependencies() {
    for dependency in "${dependencies[@]}"; do
        if ! command -v "${dependency}" &> /dev/null; then
            if ! pip3 show "${dependency}" &> /dev/null; then
                echo "Missing dependency: ${dependency}"
                exit_script="true"
            fi
        fi
    done

    if [[ "${exit_script}" == "true" ]]; then
        exit 1
    fi
}

open_pdf() {
    zathura --page=1 --mode="fullscreen" "${pdf_dir}/capitulo_${chosen_chapter}.pdf"
}

remove_img_files() {
    if test -d "${img_dir}"; then
        rm -r "${img_dir}"
    fi
    rm "${tmp_dir}/imgs_addresses.txt"
    rm "${tmp_dir}/imgs2.txt"
}

remove_tmp_files() {
    if test -d "${tmp_dir}"; then
        rm -r "${tmp_dir}"
    fi
}

remove_pdf_file() {
    if test -d "${pdf_dir}"; then
        rm -r "${pdf_dir}"
    fi
}

#################
# MAIN FUNCTION #
#################

main() {
    remove_tmp_files
    remove_pdf_file
    check_dependencies
    search_input
    mkdir --parents "${tmp_dir}"
    format_search
    get_titles_and_links
    print_mangas
    choose_manga
    choose_chapter
    get_imgs
    get_pdf
    open_pdf
    print_options
}

#####################
# VERIFYING OPTIONS # 
#####################


while [[ "${1}" ]]; do
    case "${1}" in
        -h|--help)
            print_help
            exit 0
            ;;
        -v|--version)
            echo "Versão: ${version}"
            exit 0
            ;;
        -d|--debug)
            debug_mode="true"
            ;;
        *)
            print_help
            exit 1
            ;;
    esac

    shift
done

#########
# START #
#########

main

if ! [[ ${debug_mode} ]]; then
    remove_tmp_files
fi

exit 0