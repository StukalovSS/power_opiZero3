die() { echo "$*" 1>&2 ; exit 1; }

sudo orangepi-add-overlay gpio-poweroff.dts
sudo systemctl stop power-button.service
sudo systemctl disable power-button.service

sudo cp power-button.service /etc/systemd/system/  || die "Cannot add power-button service"
sudo systemctl enable power-button.service
sudo systemctl start power-button.service
