# Linux_shell
add  /etc/init.d/  
add /usr/local/sbin/

    chmod 0777 /usr/local/sbin/*

    chmod 0755 /etc/init.d/network4g
	update-rc.d network4g defaults 99

    chmod 0755 /etc/init.d/networkfrpc
	update-rc.d networkfrpc defaults 99

    chmod 0755 /etc/init.d/smartbox
	update-rc.d smartbox defaults 99

    chmod 0755 /etc/init.d/mqttclient
	update-rc.d mqttclient defaults 99

    chmod 0755 /etc/init.d/monitoring
	update-rc.d monitoring defaults 99
