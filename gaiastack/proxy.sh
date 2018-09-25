no_proxy_ips=$(echo 192.168.56.{1..255} | sed -e 's/ /,/g')
no_proxy_hosts=$(echo tbds-192-168-56-{1..255} | sed -e 's/ /,/g')

export http_proxy="http://web-proxy.oa.com:8080"
export https_proxy="http://web-proxy.oa.com:8080"
export no_proxy="localhost,127.0.0.1,192.168.1.3,gaia*,*.oa.com,${no_proxy_ips},${no_proxy_hosts}"
