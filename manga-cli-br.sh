#!/bin/bash

# What's left to do?
# 1. Refactor the code to create less tmp files and be more efficient overall (and also faster)
# 2. Search the law to upddate disclaimer
# 3. Work on a better incrementing algorithm for next and previous chapter
# 4. Add alias to bashrc to use manga-cli-br
# 5. Deal with half chapters
# 6. Normalize img sizes to avoid black gaps between chapters
# 7. If possible, change from muitomanga to mangalivre (This solves issue #6 and mangalivre has a huge db)
#    7.1 - Working on it using selenium

########
# INFO #
########

version="0.6b"

tmp_dir="$HOME/.cache/manga-cli-br/tmp"
img_dir="${tmp_dir}/media"
pdf_dir="$HOME/.cache/manga-cli-br/pdf"

dependencies=("cat" "curl" "awk" "sed" "tr" "rm" "mkdir" "git" "zathura" "img2pdf")


####################
# FORMAT FUNCTIONS #
####################

format_search() {
    if [[ ${#manga_to_search} == 1 ]]; then
        formatted_search="${manga_to_search}"
    else
        formatted_search="$(printf "%s" "${manga_to_search}" | tr " -" "+" | sed 's/^.//')"
    fi
}

####################
# SCRAPE FUNCTIONS #
####################

get_titles_and_links() {
    not_found="$(curl --silent "https://muitomanga.com/buscar?q=${formatted_search}" | grep -c "Nenhum resultado encontrado")"

    if [ "${not_found}" -ge 1 ]; then
        echo "Mangá não foi encontrado"
        exit 0
    else
        curl --silent "https://muitomanga.com/buscar?q=${formatted_search}" | grep "</a></h3>" | awk -F'<a |</a>' '{print $2}' > "${tmp_dir}/titles-and-links"
        awk -F'/|"' '{print $4}' "${tmp_dir}/titles-and-links" > "${tmp_dir}/links" &
        awk -F'>' '{print $2}' "${tmp_dir}/titles-and-links" > "${tmp_dir}/titles"
    fi

    titles_amount=$(wc -l "${tmp_dir}/titles" | awk '{print $1}')   
}

get_chapters() {
    curl --silent "https://muitomanga.com/manga/${manga_link}" | grep "class=\"single-chapter\" data-id-cap=\"" | awk -F'"' '{print $4}' | sort -V > "${tmp_dir}/chapters"

    # chapters_total=$(wc -l "${tmp_dir}/chapters" | awk '{print $1}')
    chapters_min=$(head -n 1 "${tmp_dir}/chapters")
    chapters_max=$(tail -n 1 "${tmp_dir}/chapters")
    max_char_count=$(wc -L "${tmp_dir}/chapters" | awk '{print $1}')
}

get_imgs() {
    curl --silent "https://muitomanga.com/ler/${manga_link}/capitulo-${chosen_chapter}" | grep "imagens_cap" > "${tmp_dir}/imgs"
    imgs_max=$(curl --silent "https://muitomanga.com/ler/${manga_link}/capitulo-${chosen_chapter}" | grep "value=\"0\"" | awk -F'1 / |<' '{print $3}')

    i=2
    while [ $((i)) -lt $((imgs_max * 2 + 1)) ]; do
        awk -F'"' "{print \$$((i))}" "${tmp_dir}/imgs" >> "${tmp_dir}/imgs2"
        i=$((i+2))
    done
    
    mapfile -t img_urls < <(sed 's/\\//g' "${tmp_dir}/imgs2" | grep '\S')

    mkdir "${img_dir}"
    i=0
    for image in "${img_urls[@]}"; do
        i=$((i+1))
        curl --silent --create-dirs --header 'Referer: https://muitomanga.com/' --output "${img_dir}/${i}.jpg" "${image}" &
    done

    i=0
    for image in "${img_urls[@]}"; do
        i=$((i+1))
        echo -n "${img_dir}/${i}.jpg " >> "${tmp_dir}/imgs_addresses"
    done

    wait
}

get_pdf() {
    echo "Convertendo imagens em PDF..."
    
    if ! test -d "${pdf_dir}"; then
        mkdir "${pdf_dir}"
    fi

    img2pdf $(cat "${tmp_dir}/imgs_addresses") --output "${pdf_dir}/capitulo_${chosen_chapter}.pdf"
    
    rm -r "${img_dir}"
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
}

print_mangas() {
    i=1
    while read -r line; do
        printf "[%2s] - %s\n" "${i}" "${line}"
        i=$((i+1))
    done <"${tmp_dir}/titles"
}

print_chapters() {
    printf "Capítulos:\n\n"

    i=1
    while read -r line; do
        printf "[%${max_char_count}s] " "${line}"

        if ((i % 15 == 0)); then
            echo ""
        fi
        i=$((i+1))
    done <"${tmp_dir}/chapters"
    
    if ((i % 15 == 1)); then
        echo ""
    else
        echo ""
        echo ""
    fi
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

    echo "Mangá escolhido: $(sed -n "${chosen_manga}p" "${tmp_dir}/titles")"
    manga_title=$(sed -n "${chosen_manga}p" "${tmp_dir}/titles")
    manga_link=$(sed -n "$((chosen_manga))p" "${tmp_dir}/links")
}

choose_chapter() {
    echo -n "Escolha um capítulo: "
    read -r chosen_chapter

    # while ! [[ "$(grep -o -x "${chosen_chapter}" "${tmp_dir}/chapters")" ]]; do
    while ! grep -q -x "${chosen_chapter}" "${tmp_dir}/chapters"; do
        echo "Número fora do escopo ou capítulo não existe"
        echo -n "Escolha um capítulo: "
        read -r chosen_chapter
    done

    clear
    echo "Capítulo escolhido: ${chosen_chapter}"
    echo "Baixando capítulo..."
}

choose_option() {
    read -r chosen_option

    case "${chosen_option}" in
        n)
            chosen_chapter=$((chosen_chapter+1))
            
            if ((chosen_chapter > chapters_max)); then
                echo "Capítulo ainda não está no site!"
                chosen_chapter="${chapters_max}"
                print_options
                choose_option
            fi

            while ! grep -q -x "${chosen_chapter}" "${tmp_dir}/chapters"; do
                if ((chosen_chapter > chapters_max)); then
                    echo "Capítulo ainda não está no site!"
                    chosen_chapter="${chapters_max}"
                    print_options
                    choose_option
                fi
                chosen_chapter=$((chosen_chapter+1))
            done

            clear
            echo "Capítulo escolhido: ${chosen_chapter}"
            echo "Baixando capítulo..."

            remove_img_files
            get_imgs
            get_pdf
            clear
            open_pdf
            print_options
            choose_option
        ;;
        p)
            chosen_chapter=$((chosen_chapter-1))

            if ((chosen_chapter < chapters_min)); then
                echo "Capítulo não existe!"
                chosen_chapter="${chapters_min}"
                print_options
                choose_option
            fi

            while ! grep -o -x "${chosen_chapter}" "${tmp_dir}/chapters"; do
                echo "${chosen_chapter}"
                if ((chosen_chapter < chapters_min)); then
                    echo "Capítulo não existe!"
                    chosen_chapter="${chapters_min}"
                    print_options
                    choose_option
                fi
                chosen_chapter=$((chosen_chapter-1))
            done

            clear
            echo "Capítulo escolhido: ${chosen_chapter}"
            echo "Baixando capítulo..."

            remove_img_files
            get_imgs
            get_pdf
            clear
            open_pdf
            print_options
            choose_option
        ;;
        s)
            print_chapters
            choose_chapter
            remove_img_files
            get_imgs
            get_pdf
            clear
            open_pdf
            print_options
            choose_option
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
            choose_option
        ;;
    esac
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
    rm "${tmp_dir}/imgs_addresses"
    rm "${tmp_dir}/imgs2"
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
    get_chapters
    print_chapters
    choose_chapter
    get_imgs
    get_pdf
    clear
    open_pdf
    print_options
    choose_option
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

if ! [[ "${debug_mode}" ]]; then
    remove_tmp_files
fi

clear
exit 0