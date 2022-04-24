#!/bin/bash

# What's left to do?
# 1. Refactor the code to create less tmp files and be more efficient overall (and also faster)
# 2. Make menu with options to either
#    2.1 (n) Get next chapter 
#    2.2 (p) Get previous chapter
#    2.3 (s) Select chapter
#    2.4 (a) Search another manga
#    2.5 (q) exit
# 3. Handle tmp files when forcefully closed
# 4. Find another suitable host for translated mangas (Muitomanga sucks)
# 5. Verify if dependencies are already installed in the machine
# 6. Change README.md on Github to be more descriptive and useful
# 7. Create installation script
# 8. Decide on a directory for installation
# 9. Search the law to upddate disclaimer

########
# INFO #
########

version="0.3a"

tmp_dir="$HOME/Documentos/manga-cli-using-mangalivre/tmp"
img_dir="$HOME/Documentos/manga-cli-using-mangalivre/imgs"
pdf_dir="$HOME/Documentos/manga-cli-using-mangalivre/pdf"

# dependencies=("curl" "sed" "awk" "tr" "rm" "zathura" "cat" "echo" "wc" "grep" "mapfile" "clear" "mkdir" "img2pdf")


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

    # chapters_min=$(tail -n 1 "${tmp_dir}/chapters.txt")
    # chapters_max=$(head -n 1 "${tmp_dir}/chapters.txt")
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
    
    mkdir "${pdf_dir}"
    img2pdf $(cat "${tmp_dir}/imgs_addresses.txt") --output "${pdf_dir}/result.pdf"
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

    COMO SAIR DO LEITOR DE PDF:
    aperte q

EOF
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

    echo "Capítulo escolhido: ${chosen_chapter}"
    echo "Baixando capítulo..."
}

# input_options() {

# }

###################
# OTHER FUNCTIONS #
###################

open_pdf() {
    zathura --page=1 "${pdf_dir}/result.pdf"
}

remove_tmp_files() {
    # rm "${tmp_dir}/imgs.txt"
    # rm "${tmp_dir}/imgs2.txt"
    # rm "${tmp_dir}/imgs_addresses.txt"
    # rm "${tmp_dir}/titles.txt"
    # rm "${tmp_dir}/titles_and_links.txt"
    # rm "${tmp_dir}/chapters.txt"
    rm -r "${tmp_dir}"
}

remove_pdf_file() {
    rm -r "${pdf_dir}"
}
############
# START UP #
############

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

search_input
mkdir "${tmp_dir}"
format_search
get_titles_and_links
print_mangas
choose_manga
choose_chapter
get_imgs
get_pdf
open_pdf

if ! [[ ${debug_mode} ]]; then
    remove_tmp_files
fi