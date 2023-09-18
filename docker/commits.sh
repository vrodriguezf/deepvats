#!/bin/bash
commits=( 
    "40d3e9e8afac405a625ed7ed3a73c114459cffd9" #config yml added
    "6155c4fb3fcde57bf60b4a27f1e33e8441672cec"
    "7fc3ec936aabd2a5d17580e803212b07dadd0a0d" #base yaml
    "035233076c27622dd0445bc8abc60a7dbf1f181c" #Check variables & environment
    "983bc36e936bc539d6242ab1c422eb8d88e387bc" #02b...
    "9594f09fc7ff3b9d525ba96e98259634e9350a78" #01...
    "37427b2a5baf8428cfd1aa1b226c208549cb995f" #03..
    "197d137a4145a150850d842c0e2ebc0bf6ee47d1" #Better..
    "943c3975524eeb941e4195408ce08d3ace51d789" #Added update
    "39c9d377b56af0ef1aa392a13c80409835acd3fb" #Separados
    "2febfbf0c179be1b81a00eb9aa62437869e78e76" #Revisado inicio...
    "b2535c3e16806a99c8b6353641d30a8eb8aedaf9" #Revisado 0a..
    "31f07069bd4ff0a76de96dbd601542552c6edc6e" #Configuration separated
    "a6c838969979621fe8b3208d233594e847465f56" #Removed echo mssgs 2
    "f1fdf7e10d0047d0fd61647be5061298647470b7" #Removed echo mssgs
    "2a7691c27a6c3a0af3b31d51537c33668fde74b9" #Removed patata
    "4896cfd0f08001465915820435468783133d006b" #Removed aux 
    "e7988f45f68bf0c2aadf137853a3181a4c1d6e22" #get_jupyter_token
    "4e6d06e4d5d8339795c80403378cf3d78b1501f2" #removed extra env
)

for commit in "${commits[@]}"; do
    echo "apply $commit"
    read -n 1 -s -r -p "Presiona una tecla para continuar..."
    git cherry-pick -Xtheirs "$commit"
    if [ $? -ne 0 ]; then
        exit 1
    fi
done

echo "Todos los commits se aplicaron exitosamente."