#!/bin/bash

########
# INFO #
########

version="0.2a"
img_dir="$HOME/Documentos/manga-cli-using-mangalivre/imgs"
# dependencies=("curl" "sed" "awk" "tr" "rm")


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
    else
        curl --silent "https://muitomanga.com/buscar?q=${formatted_search}" | grep "</a></h3>" | awk -F'<a |</a>' '{print $2}' > titles-and-links.txt
        awk -F'/|"' '{print $4}' titles-and-links.txt > links.txt &
        awk -F'>' '{print $2}' titles-and-links.txt > titles.txt
    fi

    titles_amount=$(wc -l titles.txt | awk '{print $1}')
}

get_chapters() {
    curl --silent "https://muitomanga.com/manga/${manga_link}" | grep "class=\"single-chapter\" data-id-cap=\"" | awk -F'"' '{print $4}' > chapters.txt
    echo -n "[$(tail -n 1 chapters.txt)~$(head -n 1 chapters.txt)]"

    chapters_min=$(tail -n 1 chapters.txt)
    chapters_max=$(head -n 1 chapters.txt)
}

get_imgs() {
    curl --silent "https://muitomanga.com/ler/${manga_link}/capitulo-${chosen_chapter}" | grep "imagens_cap" > imgs.txt
    curl --silent "https://muitomanga.com/ler/${manga_link}/capitulo-${chosen_chapter}" | grep "value=\"0\"" | awk -F'1 / |<' '{print $3}' >> imgs.txt
    imgs_max=$(tail -n 1 imgs.txt)

    i=2
    while [ $((i)) -lt $((imgs_max * 2 + 1)) ]; do
        awk -F'"' "{print \$$((i))}" imgs.txt >> imgs2.txt
        i=$((i+2))
    done
    
    sed 's/\\//g' imgs2.txt | grep '\S' > imgs.txt
    mapfile -t img_urls < <(cat imgs.txt)

    mkdir "${img_dir}"
    i=0
    for image in "${img_urls[@]}"; do
        i=$((i+1))
        curl --silent --create-dirs --header 'Referer: https://muitomanga.com/' --output "${img_dir}/${i}.jpg" "${image}" &
    done

    i=0
    for image in "${img_urls[@]}"; do
        i=$((i+1))
        echo -n "${img_dir}/${i}.jpg " >> testing.txt
    done

    wait
}

get_pdf() {
    echo "Convertendo imagens em PDF..."
    
    img2pdf $(cat testing.txt) --output "result.pdf"
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
                           |___/                     [Versão: ${version}]

    Script em Bash para ler mangá usando seu terminal!

    Como usar: ${0} [Opção]
    Opções:
    -h ou --help: mostra esta tela
    -d ou --debug: não exclui os arquivos temporários gerados pelo script
EOF
}

print_mangas() {
    i=1
    while read -r line; do
        echo "[${i}] - ${line}"
        i=$((i+1))
    done <"titles.txt"
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

    echo "Mangá escolhido: $(sed -n "${chosen_manga}p" titles.txt)"
    manga_link=$(sed -n "$((chosen_manga))p" links.txt)
}

choose_chapter() {
    echo -n "Escolha um capítulo "
    get_chapters
    echo -n ": "
    read -r chosen_chapter

    while [ $((chosen_chapter)) -lt $((chapters_min)) ] || [ $((chosen_chapter)) -gt $((chapters_max)) ];
    do
        echo "Número fora do escopo"
        echo -n "Escolha um capítulo: "
        read -r chosen_chapter
    done

    echo "Capítulo escolhido: ${chosen_chapter}"
    echo "Baixando capítulo..."
}

############
# START UP #
############

#####################
# VERIFYING OPTIONS # 
#####################

case "${1}" in
    -h|--help)
        print_help
    ;;
    -d|--debug)
        echo "WIP"
    ;;
    *)
    ;;
esac


search_input
format_search
get_titles_and_links
print_mangas
choose_manga
choose_chapter
get_imgs
get_pdf

# rm imgs