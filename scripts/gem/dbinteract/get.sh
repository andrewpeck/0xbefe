# Check if auth file is missing or expired
if [ -e "logs/authcookies.txt" ]; then

	echo "Found auth cookies"

	gen_time_abs=$(grep -oP '\d{4}-\d{2}-\d{2} \d{2}:\d{2}:\d{2}' logs/authcookies.txt)
	gen_time=$(date -d "$gen_time_abs" +%s)
	current_time=$(date +%s)
	difference=$((current_time - gen_time))
	valid=$((difference < 43200))

	if [ "$valid" -eq 0 ]; then

		echo "Auth cookies expired"

	fi
else

	valid=0

fi

# Generate new auth file
if [ "$valid" -eq 0 ]; then

url_init="https://cmsgemdb.web.cern.ch/cmsgemdb/prod"

wget	--save-cookies logs/cookies.txt \
	--keep-session-cookies \
	--debug \
	--output-file=logs/wgetlog.txt \
	-O logs/init "$url_init"

url_auth="https://auth.cern.ch/auth/realms/cern/login-actions/authenticate"
post_auth=$(grep -o -P -m 1 '(?<=authenticate\?).*(?=" method)' logs/init | sed 's/;/\&/g')

password=$(awk '/^password/ {print$2}' credentials)
username=$(awk '/^username/ {print$2}' credentials)

echo "Logging in with user $username"

cred_auth="username=$username&password=$password&credentialId="

wget	--load-cookies logs/cookies.txt \
	--save-cookies logs/authcookies.txt \
	--keep-session-cookies \
	--debug \
	--post-data "$cred_auth" \
	--output-file=logs/wgetauthlog.txt \
	-O logs/signin "$url_auth?&$post_auth"
fi

# Get requested resource
base_url="https://cmsgemdb.web.cern.ch/cmsgemdb/prod"
vtrx_url="/show_me0vtrxp.php"
oh_url="/show_me0opto.php"

device=$(echo "$1" | tr '[:lower:]' '[:upper:]')

if [ "$device" = "OH" ]; then
	if [ "$#" -ge 2 ]; then
		wget	--load-cookies logs/authcookies.txt \
			--debug \
			--output-file=logs/get.txt \
			-O resources/oh/$2.html "$base_url$oh_url?id=ME0-OH-v2-$2"
		
		touch resources/oh/$2.txt
		runs=$(grep -P -o "(?<=event, )[0-9]{2,4}" resources/oh/$2.html)
		parsed=$(grep -o -P -m 6 '(?<=\<td\>).*(?=\</td\>)' resources/oh/$2.html)
		echo "$parsed" | awk	'NR==1 {print "ID			" $0}
					NR==2 {print "Serial Number		" $0}
					NR==3 {print "Inserted at		" $0}
					NR==4 {print "Inserted by		" $0}
					NR==5 {print "Manufacturer Name		" $0}
					NR==6 {print "Board Registration	" $0}' \
			> resources/oh/$2.txt	

	else
		wget	--load-cookies logs/authcookies.txt \
			--debug \
			--output-file=logs/get.txt \
			-O resources/oh/oh_list "$base_url/list_me0parts_opto.php"
	fi
else
	if [ "$#" -ge 2 ]; then
		wget	--load-cookies logs/authcookies.txt \
			--debug \
			--output-file=logs/get.txt \
			-O resources/vtrx/$2 "$base_url$vtrx_url?id=ME0-VTRxPlus-$2"
	else
		wget	--load-cookies logs/authcookies.txt \
			--debug \
			--output-file=logs/get.txt \
			-O resources/vtrx/vtrx_list "$base_url/list_me0parts_vtrx.php"
	fi
fi
