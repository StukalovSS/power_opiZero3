# (В процессе...)

# Управление питанием системы на базе одноплатного компьютера Orange Pi 3 LTS

Основная цель - управление питанием в стиле ATX PC, а именно - корректное завершение работы с обесточиванием системы, включая SBC и 3д-принер, после сброса кэшей записи и размонтирования файловой системы.
Работает с платами OrangePi 3 LTS

В качестве исполнительного устройства, выключающего питание системы, предлагается использовать BTT Relay https://aliexpress.ru/item/4000180758289.html

![BTT Relay](/images/btt-enclosure.jpg) 

Основная характеристика реле, обеспечившая его выбор (а не похожее MKS PWC) - задержка включения/выключения 15 секунд, позволяющая загрузить ядро Linux 
с необходимыми оверлеями без необходимости зажимать на это время (около 5 секунд) кнопку включения.

Основной недостаток - реле включает нагрузку по умолчанию, при начальной подаче сетевого напряжения 230В или пропадания сетевого напряжения.

Подробно работа данного реле рассмотрена в статье https://3dtoday.ru/blogs/vasilius-v/reversing-modulya-rele-bigtreetech-relay-v12

Возможно использование других реле, удовлетворяющих основному требованию - задержке выключения 10-15 секунд при отсутствии управляющего сигнала


![CAUTION](/images/highvoltage.png)

**ВНИМАНИЕ!** **ОПАСНО ДЛЯ ЖИЗНИ!** Действия, описываемые в данной статье, подразумевают вмешательство в электрическую часть системы (3д-принтера), напрямую подключаемую к электрической сети 230В. Все манипуляции, связанные с подключением проводов, проводить на обесточенной системе! Сетевой шнур должен быть вынут из розетки. Если вы не обладаете знаниями, навыками и допуском к работе с электроустановками, обратитесь к специалисту для выполнения описанных модификаций.

Крайне рекомендуется изолированый корпус или полукорпус для модуля BTT Relay


## Предварительные требования

* Наличие одноплатного компьютера Orange Pi 3 LTS
* Наличие BTT Relay
* Свободныe пины PL02 и PL03 на GPIO 
* Установленный официальный образ Debian [отсюда](https://github.com/bigtreetech/CB1/releases). Тестировалась версия 2.3.3

## Кнопка включения
На момент написания статьи кнопка задействуется только для включения системы, выключение производится через веб-интерфейс командой Shutdown host,
кнопкой в интерфейсе Klipperscreen, shell-командой ```sudo poweroff```. Также возможно выключение принтера по [таймауту бездействия](https://github.com/evgs/OrangePi3Lts/blob/main/power/auto_poweroff.md)

## быстрая установка 

```bash
sudo apt install gpiod
cd ~
git clone https://github.com/evgs/power_opi3lts
cd power_opi3lts
./install.sh
sudo reboot
```

## Порядок работы
* При начальной подаче питания 220В BTT Relay подаст питание на нагрузку, включая и одноплатный компьютер.
* Для выключения системы нужно или нажать на кнопку POWER, либо выполнить команду ```sudo poweroff```, либо иным способом добиться выполнения этой команды (в случае 3д-принтера - командой shutdown в вебинтерфейсе или на клипперскрине)

## Схема подключения  

Со стороны SBC сигнал удержания питания подключается к PL2 (пин 8 гребёнки GPIO) 
Также необходимо соединить землю GND SBC (например, пин 14 гребёнки GPIO).

Со стороны платы BTT Relay на одноплатник подаётся сигнал состояния кнопки. В разрыв этой цепи включён диод 1N4148 (обычный кремниевый диод). Назначение диода - предотвращение протекания тока в пин одноплатника при снятом питании.
***!!! Наличие диода обязательно !!!***

Таблица подключений

| Функция   |  OPI3LTS  | BTT Relay   |
| ----------|-----------|-------------|
| GND       | 14 - GND  | G - GND     |
| PWR HOLD  | 8  - PL02 | S (PS_ON_IN)|
| PWR BTN   | 10 - PL03 | RX/OFF      |


![wiring](/images/wiring.png)

**ВНИМАНИЕ!** При отсутствии оверлея линия управления питания включённого устройства останется сконфигурированной как вход, будет восприниматься BTT_RELAY как сигнал выключения, и через 15 секунд питание с системы, в т.ч. с одноплатника будет снято! При отладке, чтобы не разбирать схему, достаточно вместо кнопки включения поставить джампер.
Схема подключения

Подключение модуля реле выполняется согласно схеме. Преобразователь DC/DC 24В->5В на основе MP1584EN выбран условно. Такого преобразователя хватает для питания одноплатника и простой вебкамеры. Если планируется использовать более тяжёлые нагрузки, вроде адресных светодиодных лент, требуется более придирчиво выбирать преобразователь, вплоть до перехода на AC/DC.

Силовые клеммы реле LIN, LOUT включаются в разрыв сетевого провода L 230В источника питания; Клемма реле N соединяется с одноимённой клеммой N источника питания;

Кнопка включения системы подключается к разъёму BTT Relay RST.

## Подробности реализации

Оверлей создаёт объект "светодиод", подключённый к GPIO PL2, инициализируемый и зажигаемый в момент загрузки оверлея.
Светодиод будет "светиться" во время нормальной работы платы и будет "погашен" в самом конце завершения работы по команде poweroff.

Также светодиод может быть "погашен" доступом к пину через sysfs:
```console
echo "0" | sudo tee /sys/class/leds/key-pwc/brightness
```

Если нагрузка запитана - плата BTT Relay удерживает линию RX/OFF=0. При обесточенной нагрузке RX/OFF=1 (для предотвращения протекания тока от данного пина и добавлен диод 1N4148.

При нажатии кнопки POWER плата BTT Relay перезапускается, линия RX/OFF кратковременно переводится в "третье" (высокоомное) состояние, и за счёт включённой подтяжки линия PL3 прочитывается как 1, что является сигналом к выполнению процедуры выключения.

## Блокировка выключения при 3д-печати

Для предотвращения непреднамеренного выключения принтера во время печати сервис-скрипт проверяет, выполняет ли принтер задание печати, а также контролирует температуру хотенда, запрещая выключение системы, пока хотенд не остынет до 50°C
 
