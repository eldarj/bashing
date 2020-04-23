#!/bin/bash


rm -r out/inspections; mkdir out/inspections;

echo "Inspecting projects for deprecations..."
for p in projects/*; do
    cd $p
    pname=$(echo $p | cut -f2 -d/)
    echo "  Inspecting $p"
    echo "  ."
    /snap/intellij-idea-ultimate/217/bin/idea.sh inspect ~/projects/argusTeam/all-temp/$p Deprecations ~/projects/argusTeam/all-temp/out/inspections/$pname -v2 -format json

    echo "  ."
    echo "  ."
    echo ""

    cd ../../
done
