#!/bin/bash

echo 'Logging in, creating cookie...'
echo "  ."
echo "  ."
echo ""

#wget -qO- --keep-session-cookies --save-cookies cookies \
#--post-data 'j_username=ejahijagic&j_password=--<>--"' \
#https://git.ib-ci.com/j_atl_security_check &> /dev/null

fetchPom() {
  POMUrl="https://git.ib-ci.com/projects/NOC/repos/$repository/browse/pom.xml?raw"
#  wget -qO- -U "Mozilla/4.0" -O "$POMPath" --load-cookies cookies "$POMUrl"
}

echo "Fetching and parsing poms..."
while read -r repository; do
  if [ "${#repository}" -gt 0 ]; then
    POMPath="poms/$repository.pom.xml"
    fetchPom

    ESVersion=
    ESTags=('<elasticsearch\.version>' '<elasticsearch-rest\.version>')
    for XMLTag in "${ESTags[@]}"; do
      ESLine=$(grep $XMLTag $POMPath)
      if [[ -n $ESLine ]]; then
        XMLTag="${XMLTag//\\./.}"
        XMLClosingTag="${XMLTag//\</</}"
        ESVersion=$(echo $ESLine | sed "s:$XMLTag::g;s:$XMLClosingTag::g") # e.g. 6.8.0

        if [[ -n $ESVersion && $ESVersion != "7.6.2" ]]; then
          echo "  [$ESVersion] $repository has outdated es dep"

          # Git clone
          git clone "ssh://git@git.ib-ci.com:7999/noc/$repository.git" projects/$repository

          # Replace dep
          ESReplaced="${ESLine/">$ESVersion<"/">7.6.2<"}"
          sed -i "s:$ESLine:$ESReplaced:g" $POMPath
          sed -i "s:$ESLine:$ESReplaced:g" "projects/$repository/pom.xml"
	else
	  echo "  $repository has latest es dep"
        fi
      fi
    done
  fi
done < repos

echo "  ."
echo "  ."
echo ""
echo "Compiling projects..."
rm -r out; mkdir -p out/builds; touch out/compile-fail.out out/compile-ok.out;
for p in projects/*; do
  cd $p

  repository=$(echo $p | cut -f2 -d/)
  echo "  Compiling $repository"
  mvnOut="../../out/builds/$repository.out"

  mvn compile -l "$mvnOut"

  if grep -q ERROR $mvnOut; then
    echo $p >> ../../out/compile-fail.out
  else
    echo $p >> ../../out/compile-ok.out
  fi
  cd ../../
done

echo "  ."
echo "  ."
echo ""
echo "Finished compiling projects"
echo " Compiled successfully:"
while read -r p; do
    echo "  $p"
done < out/compile-ok.out

echo "  ."
echo "  ."
echo " Compiled unsuccessfully:"
while read -r p; do
    echo "  $p"
done < out/compile-fail.out

echo "  ."
echo "  ."
