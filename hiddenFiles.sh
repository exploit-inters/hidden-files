#!/bin/bash

OPERATION=$1
#--Verify the operation to be executed------------------------------------------
if [ "$OPERATION" = "-r" ]
then
	#--Start the operation of read the file into the disk-------------------------

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
			echo "@@>> COPYING LAST BLOCK"
			dd if=$2 of=./$FILENAME skip=$NEXTBLOCK seek=$FILEPOSITION bs=1
			count=$LASTBLOCKLENGTH
			((NUMOFDATABLOCKS--))
		else
			echo "@@>> COPYING"
			dd if=$2 of=./$FILENAME skip=$NEXTBLOCK seek=$FILEPOSITION bs=1 count=1016
			NEXTBLOCK=$(echo $(dd if=$2 skip=$((NEXTBLOCK+1016)) bs=1 count=8))
			FILEPOSITION=$((FILEPOSITION+1016))
			((NUMOFDATABLOCKS--))
		fi

	done
else
	if [ "$OPERATION" = "-w" ]
	then
		#--VERIFY IF THE FILE EXISTS------------------------------------------------
		if [ -f "$2" ]
		then
			#--STARTS TO WRITE THE FILE INTO THE DISK---------------------------------
			FILESIZE=$(echo $(du -b $2) | cut -d ' ' -f 1)
			LASTBLOCKLENGTH=$((FILESIZE%1016))
			FILETYPE=$(echo $2 | cut -f2 -d'.')
			echo "@@>> SEARCHING ADREESS"
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

			echo "@@>> FINDED ADREESSES:"
			echo  "###>>> ${VECTOR[@]}"

			FILEPOSITION=0
			VECTORADDRESSINDEX=0
			while [ $FILESIZE -gt 0 ]
			do
				if [ $VECTORADDRESSINDEX -eq 0 ]
				then
					echo "@@>> COPYING HEADER"

					echo $FIRSTBLOCK | dd of=$3
					seek=$((16#${VECTOR[$VECTORADDRESSINDEX]})) bs=1 count=1016

					echo  $((16#${VECTOR[$(( VECTORADDRESSINDEX+1 ))]})) | dd of=$3
					seek=$((((16#${VECTOR[$VECTORADDRESSINDEX]}))+1016)) bs=1 count=8

					(( VECTORADDRESSINDEX++ ))
				else
					dd if=$2 of=$3 skip=$FILEPOSITION
					seek=$((16#${VECTOR[$VECTORADDRESSINDEX]})) bs=1 count=1016

					echo  $((16#${VECTOR[$(( VECTORADDRESSINDEX+1 ))]})) | dd of=$3
					seek=$((((16#${VECTOR[$VECTORADDRESSINDEX]}))+1016)) bs=1 count=8

					FILESIZE=$((FILESIZE-1016))
					(( VECTORADDRESSINDEX++ ))
					FILEPOSITION=$((FILEPOSITION+1016))
				fi


			done
			echo "@@>> CHANGE DISK ID TO ${VECTOR[0]}"
			fdisk $3 >/dev/null <<_EOF_
			x
			i
			0x${VECTOR[0]}
			w
_EOF_
			else
				#--IF THE FILE DOESN'T EXISTS-------------------------------------------
				echo "@@>> FILE DOESN'T EXISTS."
			fi
		else
			#--SE NAO FOR ESCOLHIDO UMA OPERACAO VALIDA-------------------------------
			echo "@@>> Choose a valid operation. -r to read and -w to write."
	fi
fi
