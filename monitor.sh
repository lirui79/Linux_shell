#!/bin/sh
#create necessary directory
#const std::string kPathOfVersion {"/tmp/smarco/version/"};
#const std::string kPathOfUsrLocalBin {"/usr/local/bin/"};
#const std::string kPathOfUpgradeA {"/opt/upgrade/A/"};
#const std::string kPathOfUpgradeB {"/opt/upgrade/B/"};
#const std::string kPathOfTmpUpgrade {"/tmp/smarco/upgrade/"};
#const std::string kPathOfLog {"/tmp/smarco/log/"};
#const std::string kPathOfSys {"/tmp/smarco/sys/"};

lib_path="/usr/local/lib/:/usr/local/smartApp/lib/"
export LD_LIBRARY_PATH=$LD_LIBRARY_PATH:${lib_path}

if [ ! -d /opt/upgrade/A ]; then
    echo "create /opt/upgrade/A"
    mkdir -p /opt/upgrade/A
fi

if [ ! -d /opt/upgrade/B ]; then
    echo "create /opt/upgrade/B"
    mkdir -p /opt/upgrade/B
fi

if [ ! -d /tmp/smarco/version ]; then
    echo "create /tmp/smarco/version"
    mkdir -p /tmp/smarco/version
fi

if [ ! -d /tmp/smarco/sys ]; then
    echo "create /tmp/smarco/sys"
    mkdir -p /tmp/smarco/sys
fi

if [ ! -d /tmp/smarco/upgrade ]; then
    echo "create /tmp/smarco/upgrade"
    mkdir -p /tmp/smarco/upgrade
fi

if [ ! -d /tmp/smarco/log ]; then
    echo "create /tmp/smarco/log"
    mkdir -p /tmp/smarco/log
fi

while [ true ]; do

    #smarco_client
    smarco_client_runing=$(ps -ef | grep smarco_client | grep -v grep | awk '{print $2}' | wc -l)
    #进程死亡
    if [ $smarco_client_runing -eq 0 ]; then
        echo "smarco_client is missing $(date)"
        if [ -s /opt/upgrade/A/smarco_client.upg ]; then
            echo "upgrade A"
            md51=$(cat /opt/upgrade/A/smarco_client.upg)
            md52=$(md5sum /opt/upgrade/A/smarco_client | awk '{ print $1 }')
            if [ $md51 = $md52 ]; then
                echo "start smarco_client from upgrade A "
                /opt/upgrade/A/smarco_client > /dev/null &
            else
                echo "md5 checksum is not same in upgrade A" 
                rm -rf /opt/upgrade/A/smarco_client.upg 
            fi 
        elif [ -s /opt/upgrade/B/smarco_client.upg ]; then
            echo "upgrade B"
            md51=$(cat /opt/upgrade/B/smarco_client.upg)
            md52=$(md5sum /opt/upgrade/B/smarco_client | awk '{ print $1 }')
            if [ $md51 = $md52 ]; then
                echo "start smarco_client from upgrade B "
                /opt/upgrade/B/smarco_client > /dev/null &
            else    
                echo "md5 checksum is not same in upgrade B" 
                rm -rf /opt/upgrade/B/smarco_client.upg
            fi 
	    else
            echo "start smarco_client from /usr/local/bin"
            /usr/local/bin/smarco_client > /dev/null &
        fi
    fi

    #smartBox
    smartBox_pid=$(ps -ef | grep smartBox | grep -v grep | awk '{print $2}')
    if [ -s /tmp/smarco/upgrade/smartBox.lock ]; then
        #进程升级...
        echo "upgrade smartBox"
        echo $smartBox_pid
        if [ -n "$smartBox_pid" ]; then
            echo "kill smartBox"
            kill -9 $smartBox_pid
        fi
    else
        #启动进程
        echo "start smartBox"
        if [ -z "$smartBox_pid" ]; then
            /usr/local/smartApp/bin/smartBox 1 /usr/local/smartApp/log/ &
        fi
    fi

    #quectel-CM
    quectel_CM_pid=$(ps -ef | grep quectel-CM | grep -v grep | awk '{print $2}')
    if [ -s /tmp/smarco/upgrade/quectel-CM.lock ]; then
        echo "upgrade quectel-CM"
        echo $quectel_CM_pid
        if [ -n "$quectel-CM_pid" ]; then
            echo "kill quectel-CM"
            kill -9 $quectel_CM_pid
        fi
    else
        if [ -z "$quectel_CM_pid" ]; then
            echo "quectel-CM is missing $(date)"
            time=$(date +%Y-%m-%d)
            proc_log="/var/log/quectel-CM-"${time}".log"
            if [ -s /opt/upgrade/A/quectel-CM.upg ]; then
                echo "upgrade A"
                md51=$(cat /opt/upgrade/A/quectel-CM.upg)
                md52=$(md5sum /opt/upgrade/A/quectel-CM | awk '{ print $1 }')
                if [ $md51 = $md52 ]; then
                    echo "start quectel-CM from upgrade A "
                    /opt/upgrade/A/quectel-CM -f ${proc_log} &
                else
                    echo "md5 checksum is not same in upgrade A" 
                    rm -rf /opt/upgrade/A/quectel-CM.upg 
                fi 
            elif [ -s /opt/upgrade/B/quectel-CM.upg ]; then
                echo "upgrade B"
                md51=$(cat /opt/upgrade/B/quectel-CM.upg)
                md52=$(md5sum /opt/upgrade/B/quectel-CM | awk '{ print $1 }')
                if [ $md51 = $md52 ]; then
                    echo "start quectel-CM from upgrade B "
                    /opt/upgrade/B/quectel-CM -f ${proc_log} &
                else    
                    echo "md5 checksum is not same in upgrade B" 
                    rm -rf /opt/upgrade/B/quectel-CM.upg
                fi 
            else
                echo "start quectel-CM from /usr/local/bin"
                /usr/local/bin/quectel-CM -f ${proc_log} &
            fi
        fi
    fi
    sleep 3
done
