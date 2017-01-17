#!/bin/bash

OPERATION=$1
#--VERIFICA QUAL OPERACAO SERA EXECUTADA---------------------------------------
if [ "$OPERATION" = "-r" ] 
then
	#--COMECA A OPERACAO DE LER O ARQUIVO GRAVADO NO DISCO-------------------------

	DISKID=$(fdisk -l $2 | grep 'Identificador do disco' | cut -f2 -d':' | cut -f2 -d' '| cut -f2 -d'x')
	NEXTBLOCK=$((16#$DISKID))

	FIRSTBLOCK=$(echo $(dd if=$2 skip=$NEXTBLOCK bs=1 count=1016))
	FILETYPE=$(echo $FIRSTBLOCK | cut -f1 -d'|')
	LASTBLOCKLENGTH=$(echo $FIRSTBLOCK | cut -f2 -d'|')
	NUMOFDATABLOCKS=$(echo $FIRSTBLOCK | cut -f3 -d'|' | cut -f1 -d'\')
	NUMOFDATABLOCKS=$((NUMOFDATABLOCKS-1))
	FILENAME="hiddenFile.$FILETYPE"	

	NEXTBLOCK=$(echo $(dd if=$2 skip=$((NEXTBLOCK+1016)) bs=1 count=8))
	
	FILEPOSITION=0	  
	
 	while [ $NUMOFDATABLOCKS -ne 0 ]
	do
		if [ $NUMOFDATABLOCKS -eq 1 ]
		then
			echo "@@>> COPIANDO ULTIMO BLOCO"
			dd if=$2 of=./$FILENAME skip=$NEXTBLOCK seek=$FILEPOSITION bs=1 count=$LASTBLOCKLENGTH
			((NUMOFDATABLOCKS--))
		else
			echo "@@>> COPIANDO"
			dd if=$2 of=./$FILENAME skip=$NEXTBLOCK seek=$FILEPOSITION bs=1 count=1016
			NEXTBLOCK=$(echo $(dd if=$2 skip=$((NEXTBLOCK+1016)) bs=1 count=8))
			FILEPOSITION=$((FILEPOSITION+1016))
			((NUMOFDATABLOCKS--))
		fi
		
	done
else
	if [ "$OPERATION" = "-w" ]
	then
		#--VERIFICA SE O ARQUIVO PASSADO COMO ARGUMENTO EXISTE-------------------------
		if [ -f "$2" ]
		then
			#--COMECA A ESCREVER O ARQUIVO NO DISCO----------------------------------------
			FILESIZE=$(echo $(du -b $2) | cut -d ' ' -f 1)
			LASTBLOCKLENGTH=$((FILESIZE%1016))
			FILETYPE=$(echo $2 | cut -f2 -d'.')
			echo "@@>> MONTANDO VETOR DE ENDERECOS"
			ADDRESS=1024
			DISKADDRESS=$((FILESIZE/1016+2))
			FIRSTBLOCK="$FILETYPE|$LASTBLOCKLENGTH|$DISKADDRESS"
			INDEX=0
			while [ "$DISKADDRESS" -gt "$INDEX" ]
			do	
				AUX=$(xxd -l 2 -s $ADDRESS -c2 $3 | grep ": 0000" | cut -f1 -d':')
				if [ $AUX ] 
				then
					VECTOR[$INDEX]=$AUX
					(( INDEX++ ))				
				fi
				ADDRESS=$((ADDRESS+1024))
			done
					
			echo "@@>> VETOR DE ENDERECOS MONTADO COM OS VALORES:"
			echo  "###>>> ${VECTOR[@]}" 
			
			FILEPOSITION=0
			VECTORADDRESSINDEX=0	
			while [ $FILESIZE -gt 0 ]
			do
				if [ $VECTORADDRESSINDEX -eq 0 ]
				then
					echo "@@>> COPIANDO HEADER"
					echo $FIRSTBLOCK | dd of=$3 seek=$((16#${VECTOR[$VECTORADDRESSINDEX]})) bs=1 count=1016
					echo  $((16#${VECTOR[$(( VECTORADDRESSINDEX+1 ))]})) | dd of=$3 seek=$((((16#${VECTOR[$VECTORADDRESSINDEX]}))+1016)) bs=1 count=8
					
					(( VECTORADDRESSINDEX++ ))
				else
					dd if=$2 of=$3 skip=$FILEPOSITION seek=$((16#${VECTOR[$VECTORADDRESSINDEX]})) bs=1 count=1016
					echo  $((16#${VECTOR[$(( VECTORADDRESSINDEX+1 ))]})) | dd of=$3 seek=$((((16#${VECTOR[$VECTORADDRESSINDEX]}))+1016)) bs=1 count=8

					FILESIZE=$((FILESIZE-1016))
					(( VECTORADDRESSINDEX++ ))
					FILEPOSITION=$((FILEPOSITION+1016))
				fi				

			
			done
			echo "@@>> TROCANDO IDENTIFICADOR PARA ${VECTOR[0]}"
			fdisk $3 >/dev/null <<_EOF_
			x
			i
			0x${VECTOR[0]}
			w
_EOF_
			else
				#--SE O ARQUIVO PASSADO NAO EXISTIR--------------------------------------------
				echo "@@>> Arquivo invalido."		
			fi
		else
			#--SE NAO FOR ESCOLHIDO UMA OPERACAO VALIDA------------------------------------
			echo "@@>> Escolha uma operacao valida. -r para Ler e -w para escrever."
	fi
fi


