#!/bin/bash

RED='\E[1;31m'       # 红
GREEN='\E[1;32m'    # 绿
YELOW='\E[1;33m'    # 黄
BLUE='\E[1;34m'     # 蓝
PINK='\E[1;35m'     # 粉红
RES='\E[0m'          # 清除颜色

export LD_LIBRARY_PATH=../lib/:$LD_LIBRARY_PATH

trap 'onCtrlC' INT
function onCtrlC () {
    echo 'Ctrl+C received!'
    exit 0
}

function process_over () {
	local PID=$1
	local num=0
	local find=0
	while [ $num -lt 90 ]
	do
	    DPID=$(ps -ef | grep dfu-smi | grep -v grep | awk '{print $2}')
		if [ -z "$DPID" ]; then
			return 1
		fi
		num=$(( num + 1 ))
		sleep 1
	done
	echo "./dfu-smi Timeout, it will be killed!"
	kill -9 $PID
	while [ $num -lt 20 ]
	do
	    DPID=$(ps -ef | grep dfu-smi | grep -v grep | awk '{print $2}')
		if [ -z "$DPID" ]; then
			return 0
		fi
		num=$(( num + 1 ))
		sleep 1
	done
	return 0
}

function check_cardState () {
	local BNUM=$1
    local BSLOT=$2
    local BOARD_LOG=/tmp/board_${BNUM}.log
	if [ -e ${BOARD_LOG} ] ; then
		rm 	${BOARD_LOG} -rf
	fi
	./dfu-smi -d $BNUM > ${BOARD_LOG}
#	./dfu-smi -d $BNUM > ${BOARD_LOG}  &
#    PID=$!
#	process_over $PID
#	if [ $? -eq 0 ] ;then
#        return 0
#	fi
    sync
	BOARDID=$(cat ${BOARD_LOG} | grep "SmarHTC-V6624B" |  awk '{print $1}')
	if [ -z "$BOARDID" ]; then
		return 0
	fi
	BOARDID=${BOARDID:1}
	if [ $BNUM -eq $BOARDID ] ; then
	     return 1
	fi
	return 0
}

function ddr_upload () {
	######################################################### upload sdfirm*.bin
	UPLOAD_LOG=/tmp/upload.log
	UPDATE_FILE=$1
	UPDATE_NUM=$2
	UPDATE_CARD=$3
	if [ -e ${UPLOAD_LOG} ] ; then
		rm 	${UPLOAD_LOG} -rf
	fi
	##############################################################
	####build/install driver
	./build_and_install_driver.sh
	./pe_case  0x400000000 ${UPDATE_FILE}  > ${UPLOAD_LOG}  2>&1
	########################################################## upload sdfirm*.bin
	######################################################### check upload sdfirm*.bin success
	num=0
	while [ $num -lt 10 ]
	do
		if [ -e ${UPLOAD_LOG} ] ; then
			usNum=$(cat ${UPLOAD_LOG} | grep "Run addr=400000000 OK" | wc -l)
			ueNum=$(cat ${UPLOAD_LOG} | grep "ssi flash update failed" | wc -l)
			if [ $usNum -eq $UPDATE_NUM ] ; then
				echo "========================================================================="
				echo -e "upload $UPDATE_FILE ${GREEN}PASS${RES} Total Card Num:$UPDATE_NUM  ${GREEN}PASS${RES} Num:$usNum"
				echo "========================================================================="
				return  1
			fi
			if [ $ueNum -gt 0 ] ; then
				echo "========================================================================="
				echo -e "upload $UPDATE_FILE ${RED}FAILED${RES} Total Card Num:$UPDATE_NUM ${GREEN}PASS${RES} Num:$usNum ${RED}FAILED${RES} Num:$ueNum"
				echo "========================================================================="
				cat ${UPLOAD_LOG}
				return -1
			fi
		fi
		num=$(( num + 1 ))
		sleep 1
	done
	######################################################### check upload sdfirm*.bin success
	return 0
}


#update
function ssi_update () {
    UPDATE_LOG=/tmp/update.log
	UPDATE_KEY=/tmp/y.txt
	UPDATE_FILE=$1
	UPDATE_NUM=$2
	UPDATE_CARD=($3)
	CARD_STATE=($4)
	usNum=0
	ueNum=0
    if [ -e ${UPDATE_KEY} ] ; then
		rm 	${UPDATE_KEY} -rf
    fi
    echo 'y ' > /tmp/y.txt
    if [ -e ${UPDATE_LOG} ] ; then
    	rm 	${UPDATE_LOG} -rf
    fi
	for ((i=0; i < UPDATE_NUM; ++i))
	do
		if [ ${CARD_STATE[i]} -eq 0 ] ;then
			ueNum=$(( ueNum + 1 ))
			continue
		fi
#		echo  $i" "${UPDATE_CARD[i]}" update "$UPDATE_FILE
	    ./dfu-smi -n 0 -d $i -u ${UPDATE_FILE} -s 0 0< ${UPDATE_KEY}  >> ${UPDATE_LOG}  2>&1
	done
    num=0
    while [ $num -lt 10 ]
    do
		if [ -e ${UPDATE_LOG} ] ; then
			usNum=$(cat ${UPDATE_LOG} | grep "update vpu sdfirm successful" | wc -l)
			ueNum=$(cat ${UPDATE_LOG} | grep "update vpu sdfirm failed" | wc -l)
			if [ $usNum -eq $UPDATE_NUM ] ; then
				echo "========================================================================="
				echo -e "UPDATE $UPDATE_FILE ${GREEN}PASS${RES} Total Card Num:$UPDATE_NUM  ${GREEN}PASS${RES} Num:$usNum"
				echo "========================================================================="
				return 1
    		fi
			if [ $ueNum -gt 0 ] ; then
				cat ${UPDATE_LOG}
				echo "========================================================================="
				echo -e "UPDATE $UPDATE_FILE ${RED}FAILED${RES} Total Card Num:$UPDATE_NUM ${GREEN}PASS${RES} Num:$usNum ${RED}FAILED${RES} Num:$ueNum"
				echo "========================================================================="
				return -1
			fi
		fi
		num=$(( num + 1 ))
	    sleep 1
	done
	echo "========================================================================="
	return 0
}


###################################################################################
function md5_match () {
	sync
    local md5=$2
    local value=$(md5sum $1|cut -d " " -f 1)
    if [ "$value" == "$md5" ] ;then
        return 1
    else
        md5sum $1
        echo "invalid md5sum, should be $md5"
        return 0
    fi
}

function dec_md5_match () {
    local SOURCE_FILE_NAME="Kimono1_1920x1080_24.yuv.h264"
    local TARGET_FILE_MD5="8bdc01a0f87b14125f28568c2263bbc2"
    local OUTPUT_FILE="Kimono1_1920x1080_24"
    local BNUM=$1
    local BSLOT=$2
    local DEC_LOG=/tmp/dec_${BNUM}.log
	if [ -e ${DEC_LOG} ] ; then
    	rm ${DEC_LOG} -rf
	fi
	if [ -e ${OUTPUT_FILE}_${BNUM}*.yuv ] ; then
		rm ${OUTPUT_FILE}_${BNUM}*.yuv -rf
	fi

	./multi_thread_dec -i ${SOURCE_FILE_NAME} -b ${BNUM} -t 1 -o ${OUTPUT_FILE}_${BNUM} -k > ${DEC_LOG}

	md5_match ${OUTPUT_FILE}_${BNUM}*.yuv ${TARGET_FILE_MD5}
	if [ $? -eq 1 ] ;then
		echo -e "$BNUM $BSLOT dec_md5_match ${GREEN}PASS${RES}"
		return 1
	else
		echo -e "$BNUM $BSLOT dec_md5_match ${RED}FAILED${RES}"
		return 0
	fi
}

function enc_md5_match () {
    local SOURCE_FILE_NAME="crowd_run_1920_1080p15.yuv"
    local TARGET_H264_MD5="e23d8265658e893dd50f3eb792177c66"
    local TARGET_H265_MD5="f6f5ea4bfdd5cd169b4c675312bbee9f"
    local OUTPUT_FILE="crowd_run_1920_1080p15"
    local BNUM=$1
    local BSLOT=$2
    local ENCH264_LOG=/tmp/ench264_${BNUM}.log
    local ENCH265_LOG=/tmp/ench265_${BNUM}.log
	if [ -e ${ENCH264_LOG} ] ; then
    	rm ${ENCH264_LOG} -rf
	fi
	if [ -e ${OUTPUT_FILE}_${BNUM}*.h264 ] ; then
		rm ${OUTPUT_FILE}_${BNUM}*.h264 -rf
	fi

	./multi_thread_enc -i ${SOURCE_FILE_NAME} -b ${BNUM} -c h264 -t 1 -o ${OUTPUT_FILE}_${BNUM} -k > ${ENCH264_LOG}

	md5_match ${OUTPUT_FILE}_${BNUM}*.h264 ${TARGET_H264_MD5}
	if [ $? -eq 1 ] ;then
		echo -e "$BNUM $BSLOT enc_md5_match h264 ${GREEN}PASS${RES}"
		return 1
	else
		echo -e "$BNUM $BSLOT enc_md5_match h264 ${RED}FAILED${RES}"
		return 0
	fi
	if [ -e ${ENCH265_LOG} ] ; then
    	rm ${ENCH265_LOG} -rf
	fi
	if [ -e ${OUTPUT_FILE}_${BNUM}*.h265 ] ; then
		rm ${OUTPUT_FILE}_${BNUM}*.h265 -rf
	fi

	./multi_thread_enc -i ${SOURCE_FILE_NAME} -b ${BNUM} -c h265 -t 1 -o ${OUTPUT_FILE}_${BNUM} -k > ${ENCH265_LOG}

	md5_match ${OUTPUT_FILE}_${BNUM}*.h265 ${TARGET_H265_MD5}
	if [ $? -eq 1 ] ;then
		echo -e "$BNUM $BSLOT enc_md5_match h265 ${GREEN}PASS${RES}"
		return 1
	else
		echo -e "$BNUM $BSLOT enc_md5_match h265 ${RED}FAILED${RES}"
		return 0
	fi
}

function trans_md5_match () {
    local SOURCE_FILE_NAME="Kimono1_1920x1080_24.yuv.h264"
    local TARGET_H264_MD5="47d363ae2e2dc0f665d02baf1126228e"
    local TARGET_H265_MD5="1fb0b9e2b601a11b9b7a2439957a141e"
    local OUTPUT_FILE="Kimono1_1920x1080_24"
	local BNUM=$1
	local BSLOT=$2
    local TRANSH264_LOG=/tmp/tranh264_${BNUM}.log
    local TRANSH265_LOG=/tmp/tranh265_${BNUM}.log
	if [ -e ${TRANSH264_LOG} ] ; then
    	rm ${TRANSH264_LOG} -rf
	fi
	if [ -e ${OUTPUT_FILE}_${BNUM}*.h264 ] ; then
		rm ${OUTPUT_FILE}_${BNUM}*.h264 -rf
	fi

	./multi_thread_transcode -i ${SOURCE_FILE_NAME} -b ${BNUM} -c h264 -t 1 -o ${OUTPUT_FILE}_${BNUM} -k > ${TRANSH264_LOG}

	md5_match ${OUTPUT_FILE}_${BNUM}*.h264 ${TARGET_H264_MD5}
	if [ $? -eq 1 ] ;then
		echo -e "$BNUM $BSLOT trans_md5_match h264->h264 ${GREEN}PASS${RES}"
		return 1
	else
		echo -e "$BNUM $BSLOT trans_md5_match h264->h264 ${RED}FAILED${RES}"
		return 0
	fi
	if [ -e ${TRANSH265_LOG} ] ; then
    	rm ${TRANSH265_LOG} -rf
    fi
	if [ -e ${OUTPUT_FILE}_${BNUM}*.h265 ] ; then
		rm ${OUTPUT_FILE}_${BNUM}*.h265 -rf
	fi

	./multi_thread_transcode -i ${SOURCE_FILE_NAME} -b ${BNUM} -c h265 -t 1 -o ${OUTPUT_FILE}_${BNUM} -k > ${TRANSH265_LOG}

	md5_match ${OUTPUT_FILE}_${BNUM}*.h265 ${TARGET_H265_MD5}
	if [ $? -eq 1 ] ;then
		echo -e "$BNUM $BSLOT trans_md5_match h264->h265 ${GREEN}PASS${RES}"
		return 1
	else
		echo -e "$BNUM $BSLOT trans_md5_match h264->h265 ${RED}FAILED${RES}"
		return 0
	fi
}

###################################################################
function fps_match () {
    local LOG_FILE=$1
    local VAL_FPS=$2
#    array=($(cat $LOG_FILE | grep 'recent fps' | awk '{print $18}'))
    fpsNum=$(cat $LOG_FILE | grep 'recent fps' | awk '{print $NF}' | wc -l)
    array=($(cat $LOG_FILE | grep 'recent fps' | awk '{print $NF}'))
	j=1
    cntNum=$(( fpsNum - 2 ))
	if [ $fpsNum -ge 6 ] ; then
       cntNum=$(( fpsNum - 4 ))
	   j=2
	fi
	passNum=0
    for (( ;j < fpsNum; ++j))
    do
       #echo $j" "${array[j]}
       if [ `echo "${array[j]} >= ${VAL_FPS}" | bc` -eq 1 ]; then 
            passNum=$(( passNum + 1 ))
       fi
    done
	if [ $passNum -ge $cntNum ] ; then
	     return 1
	fi
    return 0
}

function dec_test_freq () {
    local SOURCE_FILE_NAME="1920x1080_h265_30fps_1569f_inner.h265"
    local BNUM=$1
    local BSLOT=$2
    local DEC_LOG=/tmp/dec_freq_${BNUM}.log
    local FPS_NUM=720
    if [ -e ${DEC_LOG} ] ; then
		rm 	${DEC_LOG} -rf
    fi
	./multi_thread_dec -i ${SOURCE_FILE_NAME} -b ${BNUM} -t 24 -R 0 > ${DEC_LOG}
    fps_match $DEC_LOG $FPS_NUM
	if [ $? -eq 1 ] ;then
		echo -e "$BNUM $BSLOT dec fps >= 720 ${GREEN}PASS${RES}"
		return 1
	else
		echo -e "$BNUM $BSLOT dec fps <  720 ${RED}FAILED${RES}"
		return 0
	fi
}

function enc_test_freq () {
#    local SOURCE_FILE_NAME="/data/1920x1080_h265_30fps_1569f_inner_yuv420p.yuv"
    local SOURCE_FILE_NAME=$3
    local BNUM=$1
    local BSLOT=$2
    local ENC_H264_LOG=/tmp/ench264_freq_${BNUM}.log
    local ENC_H265_LOG=/tmp/ench265_freq_${BNUM}.log
    local FPS_NUM=720
    local FPS_NUM2=300
    if [ -e ${ENC_H264_LOG} ] ; then
		rm 	${ENC_H264_LOG} -rf
    fi
	./multi_thread_enc -i ${SOURCE_FILE_NAME} -b ${BNUM} -c h264 -t 24 > ${ENC_H264_LOG}
    fps_match $ENC_H264_LOG $FPS_NUM
	if [ $? -eq 1 ] ;then
		echo -e "$BNUM $BSLOT enc h264 fps >= 720 ${GREEN}PASS${RES}"
		return 1
	else
        fps_match $ENC_H264_LOG $FPS_NUM2
		if [ $? -eq 1 ] ;then
		    echo -e "$BNUM $BSLOT enc h264 fps >= 300 but < 720 ${GREEN}PASS${RES}"
			echo -e "The machine hardware config too low"
			return 1
		else
			echo -e "$BNUM $BSLOT enc h264 fps <  720 ${RED}FAILED${RES}"
		    return 0
		fi
	fi

    if [ -e ${ENC_H265_LOG} ] ; then
		rm 	${ENC_H265_LOG} -rf
    fi
	./multi_thread_enc -i ${SOURCE_FILE_NAME} -b ${BNUM} -c h265 -t 24 > ${ENC_H265_LOG}
    fps_match $ENC_H265_LOG $FPS_NUM
	if [ $? -eq 1 ] ;then
		echo -e "$BNUM $BSLOT enc h265 fps >= 720 ${GREEN}PASS${RES}"
		return 1
	else
        fps_match $ENC_H265_LOG $FPS_NUM2
		if [ $? -eq 1 ] ;then
		    echo -e "$BNUM $BSLOT enc h265 fps >= 300 but < 720 ${GREEN}PASS${RES}"
			echo -e "The machine hardware config too low"
		else
			echo -e "$BNUM $BSLOT enc h265 fps <  720 ${RED}FAILED${RES}"
		    return 0
		fi
		return 1
	fi
}

function trans_test_freq () {
    local SOURCE_FILE_NAME="1920x1080_h264_30fps_1569f_inner.h264"
    local BNUM=$1
    local BSLOT=$2
    local TRANH264_LOG=/tmp/tranh264_freq_${BNUM}.log
    local TRANH265_LOG=/tmp/tranh265_freq_${BNUM}.log
    local FPS_NUM=360
    if [ -e ${TRANH264_LOG} ] ; then
		rm 	${TRANH264_LOG} -rf
    fi
	./multi_thread_transcode -i ${SOURCE_FILE_NAME} -b ${BNUM} -c h264 -t 12 > ${TRANH264_LOG}
    fps_match $TRANH264_LOG $FPS_NUM
	if [ $? -eq 1 ] ;then
		echo -e "$BNUM $BSLOT trans h264->h264 fps >= 360 ${GREEN}PASS${RES}"
		return 1
	else
		echo -e "$BNUM $BSLOT trans h264->h264 fps <  360 ${RED}FAILED${RES}"
		return 0
	fi

    if [ -e ${TRANH265_LOG} ] ; then
		rm 	${TRANH265_LOG} -rf
    fi
	./multi_thread_transcode -i ${SOURCE_FILE_NAME} -b ${BNUM} -c h265 -t 12 > ${TRANH265_LOG}
    fps_match $TRANH265_LOG $FPS_NUM
	if [ $? -eq 1 ] ;then
		echo -e "$BNUM $BSLOT trans h264->h265 fps >= 360 ${GREEN}PASS${RES}"
		return 1
	else
		echo -e "$BNUM $BSLOT trans h264->h265 fps <  360 ${RED}FAILED${RES}"
		return 0
	fi
}

####################################################################
####################################################################
####################################################################
declare -a dec_Md5=()
declare -a enc_Md5=()
declare -a tran_Md5=()
declare -a dec_Fps=()
declare -a enc_Fps=()
declare -a tran_Fps=()
declare -a card_Snum=(0 0 0 0 0 0)
declare -a card_Enum=(0 0 0 0 0 0)
declare -a card_State=()
pciCard=($(lspci | grep 103 |  awk '{print $1}'))
pciNum=$(lspci | grep 103 |  awk '{print $1}' | wc -l)
#pciCard=$(lspci | grep 103 |  awk '{print $1}')
#pciNum=$(lspci | grep 103 |  awk '{print $1}' | wc -l)


echo "========================================================================="
echo "Card total:$pciNum"

for ((i=0; i < pciNum; ++i))
do
    pciState=$(lspci -s "${pciCard[i]}" -vvv | grep LnkSta | head -n 1 |  awk '{print $1,$2,$3,$4,$5}')
    echo  $i" "${pciCard[i]}" "${pciState}
done
echo "========================================================================="
echo "Test Card State"
for ((i=0; i < pciNum; ++i))
do
		check_cardState $i ${pciCard[i]}
		if [ $? -eq 1 ] ;then
			card_State[i]=1
			echo -e  "CHECK CARD $i ${pciCard[i]} STATE ${GREEN}PASS${RES}"
		else
			card_State[i]=0
			echo -e  "CHECK CARD $i ${pciCard[i]} STATE ${RED}FAILED${RES}"
		fi
done
echo "========================================================================="
####################################################################
####################################################################
####################################################################
#PNUM=$#
PNUM=0
if [ $PNUM -gt 0 ] ; then
	upload=0
	update=0
	FIRMWARE=$1
	if [ $upload -eq 1 ] ; then
		ddr_upload ${FIRMWARE} ${pciNum} ${pciCard}
		if [ $? -eq 1 ] ;then
			echo "upload all card pass"
		else
			exit -1
		fi
	fi

	if [ $update -eq 1 ] ; then
		ssi_update ${FIRMWARE} ${pciNum} ${pciCard}
		if [ $? -eq 1 ] ;then
			echo "update all card pass, please upload sdfirm*.bin"
			exit 1
		else
			exit -1
		fi
	fi
fi

####################################################################
####################################################################
####################################################################
#### dec md5
echo "========================================================================="
echo "DEC MD5 compare"
usNum=0
ueNum=0
for ((i=0; i < pciNum; ++i))
do
	if [ ${card_State[i]} -eq 0 ] ;then
		dec_Md5[i]=0
		ueNum=$(( ueNum + 1 ))
	    continue
	fi
	dec_md5_match $i ${pciCard[i]}
	if [ $? -eq 0 ] ;then
		dec_Md5[i]=0
		ueNum=$(( ueNum + 1 ))
	else
        dec_Md5[i]=1
		usNum=$(( usNum + 1 ))
	fi
done
card_Snum[0]=${usNum}
card_Enum[0]=${ueNum}
echo "========================================================================="
if [ $ueNum -gt 0 ] ; then
  echo -e "DEC MD5 ${RED}FAILED${RES} Total Card Num:$pciNum  ${GREEN}PASS${RES} Num:$usNum  ${RED}FAILED${RES} Num:$ueNum"
else
  echo -e  "DEC MD5 ${GREEN}PASS${RES} Total Card Num:$pciNum  ${GREEN}PASS${RES} Num:$usNum"
fi
echo "========================================================================="
echo "========================================================================="
echo "ENC MD5 compare"
#### enc md5
usNum=0
ueNum=0
for ((i=0; i < pciNum; ++i))
do
	if [ ${card_State[i]} -eq 0 ] ;then
		enc_Md5[i]=0
		ueNum=$(( ueNum + 1 ))
	    continue
	fi
	enc_md5_match $i ${pciCard[i]}
	if [ $? -eq 0 ] ;then
		enc_Md5[i]=0
		ueNum=$(( ueNum + 1 ))
	else
        enc_Md5[i]=1
		usNum=$(( usNum + 1 ))
	fi
done
card_Snum[1]=${usNum}
card_Enum[1]=${ueNum}
echo "========================================================================="
if [ $ueNum -gt 0 ] ; then
  echo -e  "ENC MD5 ${RED}FAILED${RES} Total Card Num:$pciNum  ${GREEN}PASS${RES} Num:$usNum  ${RED}FAILED${RES} Num:$ueNum"
else
  echo -e  "ENC MD5 ${GREEN}PASS${RES} Total Card Num:$pciNum  ${GREEN}PASS${RES} Num:$usNum"
fi
echo "========================================================================="

echo "========================================================================="
echo "Trans MD5 compare"
#### trans md5
usNum=0
ueNum=0
for ((i=0; i < pciNum; ++i))
do
	if [ ${card_State[i]} -eq 0 ] ;then
		tran_Md5[i]=0
		ueNum=$(( ueNum + 1 ))
	    continue
	fi
	trans_md5_match $i ${pciCard[i]}
	if [ $? -eq 0 ] ;then
		tran_Md5[i]=0
		ueNum=$(( ueNum + 1 ))
	else
        tran_Md5[i]=1
		usNum=$(( usNum + 1 ))
	fi
done
card_Snum[2]=${usNum}
card_Enum[2]=${ueNum}
echo "========================================================================="
if [ $ueNum -gt 0 ] ; then
  echo -e  "Trans MD5 ${RED}FAILED${RES} Total Card Num:$pciNum  ${GREEN}PASS${RES} Num:$usNum  ${RED}FAILED${RES} Num:$ueNum"
else
  echo -e  "Trans MD5 ${GREEN}PASS${RES} Total Card Num:$pciNum  ${GREEN}PASS${RES} Num:$usNum"
fi
echo "========================================================================="
echo "========================================================================="
###

####################################################################
####################################################################
####################################################################
echo "========================================================================="
echo "DEC FPS >= 720"
#### dec fps
usNum=0
ueNum=0
for ((i=0; i < pciNum; ++i))
do
	if [ ${card_State[i]} -eq 0 ] ;then
		ueNum=$(( ueNum + 1 ))
		dec_Fps[i]=0
	    continue
	fi
	dec_test_freq $i ${pciCard[i]}
	if [ $? -eq 0 ] ;then
		ueNum=$(( ueNum + 1 ))
		dec_Fps[i]=0
    else
		usNum=$(( usNum + 1 ))
		dec_Fps[i]=1
	fi
done
card_Snum[3]=${usNum}
card_Enum[3]=${ueNum}
echo "========================================================================="
if [ $ueNum -gt 0 ] ; then
  echo -e  "DEC FPS >= 720 ${RED}FAILED${RES} Total Card Num:$pciNum  ${GREEN}PASS${RES} Num:$usNum  ${RED}FAILED${RES} Num:$ueNum"
else
  echo -e  "DEC FPS >= 720 ${GREEN}PASS${RES} Total Card Num:$pciNum  ${GREEN}PASS${RES} Num:$usNum"
fi
echo "========================================================================="
echo "========================================================================="

echo "ENC FPS >= 720"
#### enc fps
DATA_PATH=/tmp/data
if [ -d $DATA_PATH ] ; then
#	echo $DATA_PATH" exist"
	if [ ! -e $DATA_PATH/1920x1080_h265_30fps_1569f_inner_yuv420p.yuv ] ; then
		rm $DATA_PATH/* -rf
		umount $DATA_PATH
		rm $DATA_PATH -rf
		mkdir -p $DATA_PATH
		mount -t ramfs none $DATA_PATH
		cp  1920x1080_h265_30fps_1569f_inner_yuv420p.yuv  $DATA_PATH  -rf
	fi
else
	mkdir -p $DATA_PATH
	mount -t ramfs none $DATA_PATH
	cp  1920x1080_h265_30fps_1569f_inner_yuv420p.yuv  $DATA_PATH  -rf
fi

usNum=0
ueNum=0
for ((i=0; i < pciNum; ++i))
do
	if [ ${card_State[i]} -eq 0 ] ;then
		ueNum=$(( ueNum + 1 ))
		enc_Fps[i]=0
	    continue
	fi
	enc_test_freq $i ${pciCard[i]}  $DATA_PATH/1920x1080_h265_30fps_1569f_inner_yuv420p.yuv
	if [ $? -eq 0 ] ;then
		ueNum=$(( ueNum + 1 ))
		enc_Fps[i]=0
    else
		usNum=$(( usNum + 1 ))
		enc_Fps[i]=1
	fi
done
card_Snum[5]=${usNum}
card_Enum[5]=${ueNum}
echo "========================================================================="
if [ $ueNum -gt 0 ] ; then
  echo -e  "ENC FPS >= 720 ${RED}FAILED${RES} Total Card Num:$pciNum  ${GREEN}PASS${RES} Num:$usNum  ${RED}FAILED${RES} Num:$ueNum"
else
  echo -e  "ENC FPS >= 720 ${GREEN}PASS${RES} Total Card Num:$pciNum  ${GREEN}PASS${RES} Num:$usNum"
fi
echo "========================================================================="
echo "========================================================================="

echo "Trans FPS >= 360"
#### trans fps
usNum=0
ueNum=0
for ((i=0; i < pciNum; ++i))
do
	if [ ${card_State[i]} -eq 0 ] ;then
		ueNum=$(( ueNum + 1 ))
		tran_Fps[i]=0
	    continue
	fi
	trans_test_freq $i ${pciCard[i]}
	if [ $? -eq 0 ] ;then
		ueNum=$(( ueNum + 1 ))
		tran_Fps[i]=0
    else
		usNum=$(( usNum + 1 ))
		tran_Fps[i]=1
	fi
done
card_Snum[4]=${usNum}
card_Enum[4]=${ueNum}
echo "========================================================================="
if [ $ueNum -gt 0 ] ; then
  echo -e  "Trans FPS >= 360 ${RED}FAILED${RES} Total Card Num:$pciNum  ${GREEN}PASS${RES} Num:$usNum  ${RED}FAILED${RES} Num:$ueNum"
else
  echo -e  "Trans FPS >= 360 ${GREEN}PASS${RES} Total Card Num:$pciNum  ${GREEN}PASS${RES} Num:$usNum"
fi
echo "========================================================================="
echo "========================================================================="
####################################################################
####################################################################
####################################################################
##########################################################################################
echo "=====================================+==================================="
echo "================================ Total CardNum:$pciNum ========================"
echo "=====================================+==================================="
./dfu-smi
##########################################################################################

for ((i=0; i < pciNum; ++i))
do
    pciState=$(lspci -s "${pciCard[i]}" -vvv | grep LnkSta | head -n 1 |  awk '{print $1,$2,$3,$4,$5}')
    echo  $i" "${pciCard[i]}" "${pciState}
done
##########################################################################################
echo "================================ MD5 TEST ==============================="
CardSNum=0
for ((i=0; i < pciNum; ++i))
do
    usNum=0
	dec_pass=${RED}FAILED${RES}
	if [ ${dec_Md5[i]} -eq 1 ] ;then
		dec_pass=${GREEN}PASS${RES}
        usNum=$(( usNum + 1 ))
	fi
	enc_pass=${RED}FAILED${RES}
	if [ ${enc_Md5[i]} -eq 1 ] ;then
		enc_pass=${GREEN}PASS${RES}
        usNum=$(( usNum + 1 ))
	fi
	tran_pass=${RED}FAILED${RES}
	if [ ${tran_Md5[i]} -eq 1 ] ;then
		tran_pass=${GREEN}PASS${RES}
        usNum=$(( usNum + 1 ))
	fi
	echo -e  "CARDNO:$i ${pciCard[i]} dec MD5:${dec_pass} enc MD5:${enc_pass} tran MD5:${tran_pass}"
	if [ $usNum -eq 3 ] ; then
        CardSNum=$(( CardSNum + 1 ))
	fi
done
if [ $CardSNum -eq $pciNum ] ; then
	echo -e "MD5 ${GREEN}PASS${RES} CARD Num dec:${card_Snum[0]} enc:${card_Snum[1]} tran:${card_Snum[2]}"
else
	if [ $CardSNum -eq 0 ] ; then
		echo -e "MD5 ${RED}FAILED${RES} CARD Num dec:${card_Enum[0]} enc:${card_Enum[1]} tran:${card_Enum[2]}"
	else
		echo -e "MD5 ${GREEN}PASS${RES} CARD Num dec:${card_Snum[0]} enc:${card_Snum[1]} tran:${card_Snum[2]}"
		echo -e "MD5 ${RED}FAILED${RES} CARD Num dec:${card_Enum[0]} enc:${card_Enum[1]} tran:${card_Enum[2]}"
	fi
fi

echo "================================ FPS TEST ==============================="
CardSNum=0
for ((i=0; i < pciNum; ++i))
do
    usNum=0
	decf_pass=${RED}FAILED${RES}
	if [ ${dec_Fps[i]} -eq 1 ] ;then
		decf_pass=${GREEN}PASS${RES}
        usNum=$(( usNum + 1 ))
	fi
	encf_pass=${RED}FAILED${RES}
	if [ ${enc_Fps[i]} -eq 1 ] ;then
		encf_pass=${GREEN}PASS${RES}
        usNum=$(( usNum + 1 ))
	fi
	tranf_pass=${RED}FAILED${RES}
	if [ ${tran_Fps[i]} -eq 1 ] ;then
		tranf_pass=${GREEN}PASS${RES}
        usNum=$(( usNum + 1 ))
	fi
	echo -e  "CARDNO:$i ${pciCard[i]} dec FPS:${decf_pass} enc FPS:${encf_pass} tran FPS:${tranf_pass}"
	if [ $usNum -eq 3 ] ; then
        CardSNum=$(( CardSNum + 1 ))
	fi
done
if [ $CardSNum -eq $pciNum ] ; then
	echo -e  "FPS ${GREEN}PASS${RES} CARD Num dec:${card_Snum[3]} enc:${card_Snum[4]} tran:${card_Snum[5]}"
else
	if [ $CardSNum -eq 0 ] ; then
		echo -e  "FPS ${RED}FAILED${RES} CARD Num dec:${card_Enum[3]} enc:${card_Enum[4]} tran:${card_Enum[5]}"
	else
		echo -e  "FPS ${GREEN}PASS${RES} CARD Num dec:${card_Snum[3]} enc:${card_Snum[4]} tran:${card_Snum[5]}"
		echo -e  "FPS ${RED}FAILED${RES} CARD Num dec:${card_Enum[3]} enc:${card_Enum[4]} tran:${card_Enum[5]}"
	fi
fi
####################################################################
####################################################################
####################################################################
PNUM=$#
if [ $PNUM -gt 0 ] ; then
	update=1
	FIRMWARE=$1
else
	update=1
	FIRMWARE=../driver/Bin/sdfirm*.bin
fi

if [ $update -eq 1 ] ; then
	ssi_update ${FIRMWARE} ${pciNum} "${pciCard[*]}" "${card_State[*]}"
	if [ $? -eq 1 ] ;then
		echo -e "UPDATE ALL CARDS ${GREEN}PASS${RES}, please reboot system"
		exit  1
	else
		exit -1
	fi
fi
