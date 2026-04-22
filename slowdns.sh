#!/bin/bash
# ZAW SLOWDNS (DNSTT) AUTO INSTALLER + AUTO CLEAN EXPIRED

B="\e[1;34m"; G="\e[1;32m"; Y="\e[1;33m"; R="\e[1;31m"; C="\e[1;36m"; Z="\e[0m"

if [ "$(id -u)" -ne 0 ]; then
  echo -e "${R}Root (sudo -i) ဖြင့် Run ပါ${Z}"; exit 1
fi

echo -e "\n${Y}🌐 SlowDNS အတွက် NS (Nameserver) Domain ကို ရိုက်ထည့်ပါ${Z}"
echo -e "${C}(ဥပမာ - ns.zawvpn.com)${Z}"
read -p "➔ NS Domain: " NSDOMAIN
if [[ -z "$NSDOMAIN" ]]; then
    echo -e "${R}NS Domain မရှိဘဲ SlowDNS တပ်ဆင်၍ မရပါ။ ထွက်ပါမည်။${Z}"
    exit 1
fi

echo -e "${Y}📦 Packages များ တပ်ဆင်နေပါသည်...${Z}"
apt update -y >/dev/null 2>&1
apt install -y wget curl git iptables dropbear >/dev/null 2>&1

# Dropbear ကို Local Port 109 တွင် ဖွင့်ပေးခြင်း
sed -i 's/NO_START=1/NO_START=0/g' /etc/default/dropbear
sed -i 's/DROPBEAR_PORT=22/DROPBEAR_PORT=109/g' /etc/default/dropbear
systemctl restart dropbear

echo -e "${Y}⬇️ DNSTT (SlowDNS) Engine ကို တပ်ဆင်နေပါသည်...${Z}"
mkdir -p /etc/slowdns
cd /etc/slowdns

wget -qO dnstt-server https://github.com/mmmray/dnstt/raw/master/dnstt-server
chmod +x dnstt-server
cp dnstt-server /usr/local/bin/

./dnstt-server -gen > keys.txt
PUB_KEY=$(grep "pubkey" keys.txt | awk '{print $2}')
PRIV_KEY=$(grep "privkey" keys.txt | awk '{print $2}')
echo "$PUB_KEY" > /etc/slowdns/server.pub
echo "$PRIV_KEY" > /etc/slowdns/server.key
echo "$NSDOMAIN" > /etc/slowdns/nsdomain

iptables -I INPUT -p udp --dport 5300 -j ACCEPT
iptables -t nat -I PREROUTING -p udp --dport 53 -j REDIRECT --to-ports 5300
netfilter-persistent save >/dev/null 2>&1 || true

cat > /etc/systemd/system/slowdns.service <<EOF
[Unit]
Description=ZAW SlowDNS Server
After=network.target

[Service]
Type=simple
User=root
ExecStart=/usr/local/bin/dnstt-server -udp :5300 -privkey-file /etc/slowdns/server.key $NSDOMAIN 127.0.0.1:109
Restart=always
RestartSec=3

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable --now slowdns
systemctl restart slowdns

# === 🔴 AUTO-CLEAN (ည ၁၂ နာရီတိုင်း အလိုလို အကောင့်ဖျက်မည့် စနစ်) 🔴 ===
echo -e "${Y}🧹 Auto-Delete (သက်တမ်းလွန် အကောင့်ဖျက်စနစ်) ထည့်သွင်းနေပါသည်...${Z}"
cat > /usr/local/bin/slowdns_cleaner << 'EOF'
#!/bin/bash
today_days=$(($(date +%s) / 86400))
for user in $(awk -F: '$3 >= 1000 && $1 != "nobody" {print $1}' /etc/passwd); do
    exp_days=$(awk -F: -v u="$user" '$1 == u {print $8}' /etc/shadow)
    if [[ -n "$exp_days" && "$exp_days" =~ ^[0-9]+$ ]]; then
        if (( exp_days < today_days )); then
            userdel -f "$user" >/dev/null 2>&1
        fi
    fi
done
EOF

chmod +x /usr/local/bin/slowdns_cleaner
crontab -l 2>/dev/null | grep -v "slowdns_cleaner" | crontab - || true
(crontab -l 2>/dev/null; echo "1 0 * * * /usr/local/bin/slowdns_cleaner >/dev/null 2>&1") | crontab -

# 🔴 FIX: Bro ရဲ့ GitHub Link အသစ်ကို တိုက်ရိုက် ထည့်ပေးထားပါသည် 🔴
echo -e "${Y}📋 SlowDNS CLI Menu ထည့်သွင်းနေပါသည်...${Z}"
wget -qO /usr/bin/smenu "https://raw.githubusercontent.com/zaw-myscript/Zaw2026-new-slowdns-Script/refs/heads/main/smenu"
chmod +x /usr/bin/smenu

clear
echo -e "\033[1;32m✅ SlowDNS (DNSTT) Server နှင့် Auto-Clean စနစ် အောင်မြင်စွာ တပ်ဆင်ပြီးပါပြီ!\033[0m"
echo -e "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo -e "🌐 NS Domain : \033[1;33m$NSDOMAIN\033[0m"
echo -e "🔑 Public Key: \033[1;33m$PUB_KEY\033[0m"
echo -e "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo -e "➔ အကောင့်စီမံရန် Terminal တွင် \033[1;36msmenu\033[0m ဟု ရိုက်ထည့်ပါ။"
