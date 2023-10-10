# Create-NordVPNMobileConfig
Gatters all NordVPN IKEv2 servers via the API and creates .mobileconfig files with custom data  (and installs the NordVPN Root CA on your Apple TV)

How to use:

1. Run the script
   
2. Go to: https://my.nordaccount.com/de/dashboard/nordvpn/manual-configuration/ and note down your username and password
   
3. Select a folder where to store all the .mobileconfig (VPN configuration payloads) files in -> take care: over 5000 files
   
4. Type your username when asked
   
5. Type your password when asked
   
6. Wait until the script finishes

7. Download "Apple Configurator" from the App Store on your Mac

8. Run "Apple Configurator" and choose "Paired Devices" in the top navigation bar

9. On your Apple TV: Open Settings > Remotes and Devices > Remote-App and Devices

10. If the devices are on the same network, you can pair your Apple TV with your Mac using the 6-digit code

11. Once paired click: "Add" > "Profiles" > Select all .mobileconfig files for the specific VPN connections you want

12. Install the profiles on your Apple TV
