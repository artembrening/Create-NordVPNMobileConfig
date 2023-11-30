# Load the required assembly for the Windows Forms FolderBrowserDialog.
Add-Type -AssemblyName System.Windows.Forms

# Create a new folder browser dialog object.
$browser = New-Object System.Windows.Forms.FolderBrowserDialog
# Show the folder browser dialog and store the result (either OK or Cancel).
$null = $browser.ShowDialog()
# Get the selected path from the folder browser dialog.
$OutputPath = $browser.SelectedPath

# Check if a path was actually selected.
if ($OutputPath -ne $null){

    # Prompt the user for their VPN credentials.
    $UsernameVPN = Read-Host "Username"
    $PasswordVPN = Read-Host "Password"

    # Fetch the NordVPN server list using their API and parse the JSON result.
    $Servers = ConvertFrom-Json (Invoke-WebRequest -Uri "https://nordvpn.com/api/server" -UseBasicParsing).Content

    # Assign the fetched servers to another variable for further processing.
    $data = $Servers

    # Define a function to flatten nested objects.
    function Flatten-Object {
        param($Object, $Prefix)

        $result = @{}

        # Iterate through all properties of the given object.
        foreach ($property in $Object.PSObject.Properties) {
            $key = $property.Name
            $value = $property.Value

            # Check if the property value is an array and process it.
            if ($value -is [System.Array]) {
                for ($i=0; $i -lt $value.Length; $i++) {
                    $newKey = "${Prefix}${key}_${i}"
                    $result += Flatten-Object -Object $value[$i] -Prefix "${newKey}_"
                }
            }
            # Check if the property value is another object and process it.
            elseif ($value -is [PSCustomObject]) {
                $result += Flatten-Object -Object $value -Prefix "${Prefix}${key}_"
            }
            # If the property value is neither an array nor an object, just add it to the result.
            else {
                $result["${Prefix}${key}"] = $value
            }
        }

        return $result
    }

    # Apply the flattening function to each item in the data.
    $flattenedData = $data | ForEach-Object {
        $flatObject = Flatten-Object -Object $_ -Prefix ""
        [PSCustomObject]$flatObject
    }

    # Filter the flattened data to get a list of servers that support IKEv2, and sort them by name.
    $ServerList = $flattenedData | select name, country, domain, categories_0_name, ip_address, features_ikev2 | Where {$_.features_ikev2 -eq "True"} | Sort-Object -Property name

	# Access the 'countries' column
	
	$countries = $flattenedData | Select-Object -ExpandProperty country
	
	# Remove duplicates
	
	$uniqueCountries = $countries | Select-Object -Unique

	foreach ($uniqueCountry in $uniqueCountries){

		if ((Test-Path "$OutputPath\$uniqueCountry") -ne $true){

			New-Item -ItemType Directory -Path "$OutputPath\$uniqueCountry"

			Write-Host "Created directory for $uniqueCountry at "$OutputPath\$uniqueCountry" as it didn't exist yet at the output path."

		}

	}
	
    # Process each server in the list.

    foreach ($Server in $ServerList){

        [string]$vpnName = $Server.domain

        # Generate new UUIDs

        $payloadUUID = [guid]::NewGuid().ToString()
        $mainPayloadUUID = [guid]::NewGuid().ToString()

        # Prepare the XML content
        $xmlContent = @"
        <?xml version="1.0" encoding="UTF-8"?>
        <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
        <plist version="1.0">
        <dict>
	    <key>PayloadContent</key>
	    <array>
		<dict>
			<key>IKEv2</key>
			<dict>
				<key>AuthName</key>
				<string>{3}</string>
				<key>AuthPassword</key>
				<string>{4}</string>
				<key>AuthenticationMethod</key>
				<string>None</string>
				<key>ChildSecurityAssociationParameters</key>
				<dict>
					<key>DiffieHellmanGroup</key>
					<integer>20</integer>
					<key>EncryptionAlgorithm</key>
					<string>AES-256</string>
					<key>IntegrityAlgorithm</key>
					<string>SHA2-384</string>
					<key>LifeTimeInMinutes</key>
					<integer>1440</integer>
				</dict>
				<key>DeadPeerDetectionRate</key>
				<string>Medium</string>
				<key>DisableMOBIKE</key>
				<integer>0</integer>
				<key>DisableRedirect</key>
				<integer>0</integer>
				<key>EnableCertificateRevocationCheck</key>
				<integer>0</integer>
				<key>EnablePFS</key>
				<true/>
				<key>ExtendedAuthEnabled</key>
				<true/>
				<key>IKESecurityAssociationParameters</key>
				<dict>
					<key>DiffieHellmanGroup</key>
					<integer>20</integer>
					<key>EncryptionAlgorithm</key>
					<string>AES-256-GCM</string>
					<key>IntegrityAlgorithm</key>
					<string>SHA2-384</string>
					<key>LifeTimeInMinutes</key>
					<integer>1440</integer>
				</dict>
				<key>OnDemandEnabled</key>
				<integer>1</integer>
				<key>OnDemandRules</key>
				<array>
					<dict>
						<key>Action</key>
						<string>Connect</string>
					</dict>
				</array>
				<key>RemoteAddress</key>
				<string>{0}</string>
				<key>RemoteIdentifier</key>
				<string>{0}</string>
				<key>UseConfigurationAttributeInternalIPSubnet</key>
				<integer>0</integer>
			</dict>
			<key>PayloadDescription</key>
			<string>Configures VPN settings</string>
			<key>PayloadDisplayName</key>
			<string>VPN</string>
			<key>PayloadIdentifier</key>
			<string>com.apple.vpn.managed.{1}</string>
			<key>PayloadType</key>
			<string>com.apple.vpn.managed</string>
			<key>PayloadUUID</key>
			<string>{1}</string>
			<key>PayloadVersion</key>
			<integer>1</integer>
			<key>Proxies</key>
			<dict>
				<key>HTTPEnable</key>
				<integer>0</integer>
				<key>HTTPSEnable</key>
				<integer>0</integer>
			</dict>
			<key>UserDefinedName</key>
			<string>{0}</string>
			<key>VPNType</key>
			<string>IKEv2</string>
		</dict>
		<dict>
			<key>PayloadCertificateFileName</key>
			<string>root.der</string>
			<key>PayloadContent</key>
			<data>
			MIIFCjCCAvKgAwIBAgIBATANBgkqhkiG9w0BAQ0FADA5MQswCQYD
			VQQGEwJQQTEQMA4GA1UEChMHTm9yZFZQTjEYMBYGA1UEAxMPTm9y
			ZFZQTiBSb290IENBMB4XDTE2MDEwMTAwMDAwMFoXDTM1MTIzMTIz
			NTk1OVowOTELMAkGA1UEBhMCUEExEDAOBgNVBAoTB05vcmRWUE4x
			GDAWBgNVBAMTD05vcmRWUE4gUm9vdCBDQTCCAiIwDQYJKoZIhvcN
			AQEBBQADggIPADCCAgoCggIBAMkr/BYhyo0F2upsIMXwC6QvkZps
			3NN2/eQFkfQIS1gql0aejsKsEnmY0Kaon8uZCTXPsRH1gQNgg5D2
			gixdd1mJUvV3dE3y9FJrXMoDkXdCGBodvKJyU6lcfEVF6/UxHcbB
			guZK9UtRHS9eJYm3rpL/5huQMCppX7kUeQ8dpCwd3iKITqwd1Zud
			DqsWaU0vqzC2H55IyaZ/5/TnCk31Q1UP6BksbbuRcwOVskEDsm6Y
			oWDnn/IIzGOYnFJRzQH5jTz3j1QBvRIuQuBuvUkfhx1FEwhwZigr
			cxXuMP+QgM54kezgziJUaZcOM2zF3lvrwMvXDMfNeIoJABv9ljw9
			69xQ8czQCU5lMVmA37ltv5Ec9U5hZuwk/9QO1Z+d/r6Jx0mlurS8
			gnCAKJgwa3kyZw6e4FZ8mYL4vpRRhPdvRTWCMJkeB4yBHyhxUmTR
			gJHm6YR3D6hcFAc9cQcTEl/I60tMdz33G6m0O42sQt/+AR3YCY/R
			usWVBJB/qNS94EtNtj8iaebCQW1jHAhvGmFILVR9lzD0EzWKHkvy
			WEjmUVRgCDd6Ne3eFRNS73gdv/C3l5boYySeu4exkEYVxVRn8DhC
			xs0MnkMHWFK6MyzXCCn+JnWFDYPfDKHvpff/kLDobtPBf+Lbch5w
			Qy9quY27xaj0XwLyjOltpiSTLWae/Q4vAgMBAAGjHTAbMAwGA1Ud
			EwQFMAMBAf8wCwYDVR0PBAQDAgEGMA0GCSqGSIb3DQEBDQUAA4IC
			AQC9fUL2sZPxIN2mD32VeNySTgZlCEdVmlq471o/bDMP4B8gnQes
			FRtXY2ZCjs50Jm73B2LViL9qlREmI6vE5IC8IsRBJSV4ce1WYxyX
			ro5rmVg/k6a10rlsbK/eg//GHoJxDdXDOokLUSnxt7gk3QKpX6eC
			dh67p0PuWm/7WUJQxH2SDxsT9vB/iZriTIEe/ILoOQF0Aqp7AgNC
			cLcLAmbxXQkXYCCSB35Vp06u+eTWjG0/pyS5V14stGtw+fA0DJp5
			ZJV4eqJ5LqxMlYvEZ/qKTEdoCeaXv2QEmN6dVqjDoTAok0t5u4YR
			XzEVCfXAC3ocplNdtCA72wjFJcSbfif4BSC8bDACTXtnPC7nD0Vn
			dZLp+RiNLeiENhk0oTC+UVdSc+n2nJOzkCK0vYu0Ads4JGIB7g8I
			B3z2t9ICmsWrgnhdNdcOe15BincrGA8avQ1cWXsfIKEjbrnEuEk9
			b5jel6NfHtPKoHc9mDpRdNPISeVawDBM1mJChneHt59Nh8Gah74+
			TM1jBsw4fhJPvoc7Atcg740JErb904mZfkIEmojCVPhBHVQ9LHBA
			dM8qFI2kRK0IynOmAZhexlP/aT/kpEsEPyaZQlnBn3An1CRz8h0S
			PApL8PytggYKeQmRhl499+6jLxcZ2IegLfqq41dzIjwHwTMplg+1
			pKIOVojpWA==
			</data>
			<key>PayloadDescription</key>
			<string>CA-Stammzertifikat hinzufügen</string>
			<key>PayloadDisplayName</key>
			<string>NordVPN Root CA</string>
			<key>PayloadIdentifier</key>
			<string>com.apple.security.root.8F5CE61E-1C3F-45AE-9A93-A38C05C566EA</string>
			<key>PayloadType</key>
			<string>com.apple.security.root</string>
			<key>PayloadUUID</key>
			<string>8F5CE61E-1C3F-45AE-9A93-A38C05C566EA</string>
			<key>PayloadVersion</key>
			<integer>1</integer>
		</dict>
	    </array>
	    <key>PayloadDisplayName</key>
	    <string>IKEv2 VPN configuration ({0})</string>
	    <key>PayloadIdentifier</key>
	    <string>com.artembrening.vpn.{2}</string>
	    <key>PayloadRemovalDisallowed</key>
	    <false/>
	    <key>PayloadType</key>
	    <string>Configuration</string>
	    <key>PayloadUUID</key>
	    <string>{2}</string>
	    <key>PayloadVersion</key>
	    <integer>1</integer>
        </dict>
        </plist>
"@ -f $vpnName, $payloadUUID, $mainPayloadUUID, $UsernameVPN, $PasswordVPN

# Save to a .mobileconfig file
$xmlContent | Out-File "$OutputPath\$($Server.country)\$vpnName.mobileconfig"

Write-Host "File saved to $OutputPath\$($Server.country)\$vpnName.mobileconfig"

}

}