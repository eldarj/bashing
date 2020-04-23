#!/bin/bash
CROSS="\U2716"
CHECK="\U2714"
GREENC="\e[32m"
REDC="\e[31m"
NORMC="\e[0m"

function doAuth() {
  printf $NORMF "Logging in, creating auth cookie..."
  wget -qO- --keep-session-cookies --save-cookies cookies\
    --post-data 'j_username=ejahijagic&j_password=--<>--"'\
    https://git.ib-ci.com/j_atl_security_check &> /dev/null
}

function isESVersionOutdated() {
  local POMPath=$1
  local ESTag=$(echo $2 | sed 's:\\::g')
  local ESDepLine=$3

  ESDepLineNumber=$(grep -n $ESDepLine $POMPath | cut -f1 -d:)
  ESVersion=$(echo $ESDepLine | sed "s:</\?$ESTag>::g")

  if [ $ESVersion == '7.6.2' ]; then
    printf "$GREENC%s $CHECK\n" "$repository already has ES client latest dependency" | tee -a out/es-deps.out
    return
  fi
  printf "$NORMC%s \n" "$repository doesn't have latest ES client, cloning project..."

  git clone "ssh://git@git.ib-ci.com:7999/noc/$repository.git" projects/$repository

  printf "$NORMC%s \n" "Updating $repository's ES client dependency ($POMPath)"
  ESNewDepLine="<$ESTag>7.6.2</$ESTag>"
  TargetPOMPath="projects/$repository/pom.xml"
  echo " - $POMPath"
  echo " - $TargetPOMPath"
  echo " - $repository"
  echo " - $ESTag"
  echo " - $ESDepLine"
  echo " - $ESNewDepLine"
  echo " - $ESDepLineNumber"

  printf "$NORMC%s \n" "Replacing $ESDepLine with $ESNewDepLine, on line: $ESDepLineNumber"
  sed -i "s:$ESDepLine:$ESNewDepLine:g" $TargetPOMPath
  sed -i "s:$ESDepLine:$ESNewDepLine:g" $POMPath

  printf "$GREENC%s $CHECK\n" "Updated $repository's ES client dependency" | tee -a out/es-deps.out
}

function fetchPomsFromGit() {
  printf "\n$NORMC%s \n" "Fetching $repository's pom.xml, checking for ES client..."
  # repoServicePomUrl="https://git.ib-ci.com/projects/NOC/repos/$repository/browse/pom.xml?raw"
  # wget -qO- -U "Mozilla/4.0" -O $POMPath --load-cookies cookies $repoServicePomUrl
}

##################################################################################################################

# wget https://git.ib-ci.com/projects/NOC

# Remove stuff we don't need from the /NOC page
# cat allrepos.txt | sed 's:Repository::g;s:\[DEPRECATED\]::g;s:\bCRITICAL\b::g;s:Fork::g;s:Web.*::g'

# Make
mkdir poms projects builds out

#doAuth

rm out/es-deps.out
touch out/es-deps.out
while read repository; do
  if [ "${#repository}" -gt 0 ]
  then
      POMPath="poms/$repository.pom.xml"

      # Fetch poms from git
      # First check poms only, then clone and update poms that don't use the latest ES dep.
      fetchPomsFromGit
      ESTag="elasticsearch\.version"
      ESDepLine=$(grep $ESTag $POMPath)
      ESRestTag="elasticsearch-rest\.version"
      ESRestLine=$(grep $ESRestTag $POMPath)

      if [ ${#ESDepLine} -gt 0 ]; then
        isESVersionOutdated $POMPath $ESTag $ESDepLine
      elif [ ${#ESRestLine} -gt 0 ]; then
        isESVersionOutdated $POMPath $ESRestTag $ESRestLine
      else
          printf "$GREENC%s $CHECK\n" "$repository doesn't have any ES client dep" | tee -a out/es-deps.out
      fi
  fi
done < repos

# Run mvn compile for every project
function buildProjects() {
  rm out/compile-fail.out out/compile-ok.out
  touch out/compile-fail.out out/compile-ok.out
  for project in projects/*; do
    printf "\n$NORMC%s \n.\n.\n" "Running mvn compile in $project"

    repository=$(echo $project | cut -f3 -d/)
    cd $project
    mvn compile -l ../../builds/$repository-mvn-compile.out

    printf ".\n.\n"
    if grep -q ERROR mvncompile.out; then
      printf "$REDC%s $CROSS\n" "$project: mvn compile FAILED" | tee -a ../../../out/compile-fail.out
    else
      printf "$GREENC%s $CHECK\n" "$project: mvn compile OK" | tee -a ../../../out/compile-ok.out
    fi
    cd ../../../
  done
}

# If every build was successful, run deprecation inspection
function inspectDeprecations() {
  if [ -s out/compile-fail.out ]; then
    echo "There are compilation errors!"
    exit
  fi

  echo "Running deprecation inspection..."
}

buildProjects
inspectDeprecations

