export GREEN="\e[32m"
export RED="\e[31m"
export ENDCOLOR="\e[0m"

function log(){
  color="$1"
  shift
  >&2 echo -e "${color}${*}${ENDCOLOR}"
}
