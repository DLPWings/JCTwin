--[[ 
MIT License

Copyright (c) [2021] [Juan de la Parra - DLP Wings]

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE. ]]





-- Config
local fuelAlarmL = 30 --Default 30%
local fuelAlarmR = 30 --Default 30%
local fuelAlarmRepeat = 10000 --milliseconds

-- App variables
local sensorIdL = 0
local sensorIdR = 0
local demoMode = false
local demoModeCtrl

local resetReminder
local resetReminderFile
local resetDoneL = false
local resetDoneR = false

local booleanSelect = {"Yes", "No"}
local inputControls = {"P1", "P2", "P3", "P4"}

--Alarm
local fuelAlarmFile
local fuelAlarmPlayedL = false
local fuelAlarmPlayedR = false
local alarmVoice = true
local fuelAlarmArmedL = false
local fuelAlarmArmedR = false
local lastAlarmL = 0
local lastAlarmR = 0

--Telemetry Variables
local RPMValueL = 0
local EGTValueL = 0
local ECUVValueL = 0
local EcuBattValueL = 0
local FuelValueL = 0
local StatusCodeL = 0
local MessageCodeL = 0


local RPMValueR = 0
local EGTValueR = 0
local ECUVValueR = 0
local EcuBattValueR = 0
local FuelValueR = 0
local StatusCodeR = 0
local MessageCodeR = 0


-- Create an arrow
local renShape=lcd.renderer()
local largeHandle = {
    { 1, -46},
    { -1, -46},
    {-3, -18},
    { 0, -18},
    { 3, -18}
    }
local alarmHandle = {
    { 5, -48},
    { -5, -48},
    { 0, -36}
    }
local mediumHandle = {
    { 1, -39},
    { -1, -39},
    {-3, -16},
    { 0, -16},
    { 3, -16}
    }
local smallHandle = {
    { 1, -25},
    { -1, -25},
    {-2, -10},
    { 0, -10},
    { 2, -10}
    }
local flameOutCodes = {
    [12] = true, --"No RX"
    [15] = true, --"Failsafe"
    [19] = true, --"Turbine Comm Error"
    [22] = true, --"Low RPM"
    [23] = true  --"RPM Sensor Error"
}

local jcLogo
local sensorsAvailable = {}

local flameOutL = false
local flameOutR = false
local flameOutResetL = false
local flameOutResetR = false
local flameOutTC_Enabled = false
local flameOutFileL
local flameOutFileR
local flameOutRepeat = 3000
local lastFlameOutRepeat = 0
local inputThrottle = 4
local inputThrottlePos = -95

collectgarbage()

local function drawShape(col, row, shape, rotation)
    local sinShape = math.sin(rotation)
    local cosShape = math.cos(rotation)
    renShape:reset()
    for index, point in pairs(shape) do
    renShape:addPoint(
    col + (point[1] * cosShape - point[2] * sinShape + 0.5),
    row + (point[1] * sinShape + point[2] * cosShape + 0.5)
    )
    end
    renShape:renderPolygon()
end


--Form functions
local function sensorChangedL(value)
    if(value and value >=0) then
        sensorIdL=sensorsAvailable[value].id
    else
        sensorIdL = 0
    end
    system.pSave("SensorIdL",sensorIdL)
end

local function sensorChangedR(value)
    if(value and value >=0) then
        sensorIdR=sensorsAvailable[value].id
    else
        sensorIdR = 0
    end
    system.pSave("SensorIdR",sensorIdR)
end

local function inputThrottleChanged(value)
    inputThrottle = value
    print(inputThrottle)
    system.pSave("inputThrottle",inputThrottle)

end

local function inputThrottlePosChanged(value)
    inputThrottlePos = value
    system.pSave("inputThrottlePosChanged",inputThrottlePos)

end

local function fuelAlarmChanged(value)
    fuelAlarmL = value
    system.pSave("FuelAlarm",value)
end

local function fuelAlarmRepeatChanged(value)
    fuelAlarmRepeat = value*1000
    system.pSave("FuelAlarmRepeat",fuelAlarmRepeat)
end

local function flameOutFileLChanged(value)
	flameOutFileL=value
	system.pSave("flameOutFileL",value)
end
local function flameOutFileRChanged(value)
	flameOutFileR=value
	system.pSave("flameOutFileR",value)
end

local function flameOutRepeatChanged(value)
    flameOutRepeat = value*1000
    system.pSave("flameOutRepeat",flameOutRepeat)
end

local function fuelAlarmFileChanged(value)
	fuelAlarmFile=value
	system.pSave("FuelAlarmFile",value)
end

local function resetReminderFileChanged(value)
	resetReminderFile=value
	system.pSave("ResetReminderFile",value)
end

local function alarmVoiceValueChanged(value)
    alarmVoice = value
    system.pSave("AlarmVoice",alarmVoice)
end

local function resetReminderChanged(value)
    resetReminder = value
    system.pSave("ResetReminder",resetReminder)
end

local function demoModeChanged(value)
    demoMode = not value
    form.setValue(demoModeCtrl,demoMode)
    if demoMode then system.pSave("DemoMode",1) else system.pSave("DemoMode",0) end
end

local function decodeStatus(statusID)

    if statusID == 10 then     return "Stop"
    elseif statusID == 20 then return "Glow Test"
    elseif statusID == 30 then return "Starter Test"
    elseif statusID == 31 then return "Prime Fuel"
    elseif statusID == 32 then return "Prime Burner"
    elseif statusID == 40 then return "Manual Cooling"
    elseif statusID == 41 then return "Auto Cooling"
    elseif statusID == 51 then return "Igniter Heat"
    elseif statusID == 52 then return "Ignition"
    elseif statusID == 53 then return "Preheat"
    elseif statusID == 54 then return "Switchover"
    elseif statusID == 55 then return "To Idle"
    elseif statusID == 56 then return "Running"
    elseif statusID == 62 then return "Stop Error"
    else                       return "No Data"
    end
end

local function decodeMessage(messageID)

    if messageID == 1 then     return "Ignition Error"
    elseif messageID == 2 then return "Preheat Error"
    elseif messageID == 3 then return "Switchover Error"
    elseif messageID == 4 then return "Starter Motor Error"
    elseif messageID == 5 then return "To Idle Error"
    elseif messageID == 6 then return "Acceleration Error"
    elseif messageID == 7 then return "Igniter Bad"
    elseif messageID == 8 then return "Min Pump Ok"
    elseif messageID == 9 then return "Max Pump Ok"
    elseif messageID == 10 then return "Low RX Battery"
    elseif messageID == 11 then return "Low ECU Battery"
    elseif messageID == 12 then return "No RX"
    elseif messageID == 13 then return "Trim Down"
    elseif messageID == 14 then return "Trim Up"
    elseif messageID == 15 then return "Failsafe"
    elseif messageID == 16 then return "Full"
    elseif messageID == 17 then return "RX Setup Error"
    elseif messageID == 18 then return "Temp Sensor Error"
    elseif messageID == 19 then return "Turbine Comm Error"
    elseif messageID == 20 then return "Max Temp"
    elseif messageID == 21 then return "Max Amperes"
    elseif messageID == 22 then return "Low RPM"
    elseif messageID == 23 then return "RPM Sensor Error"
    elseif messageID == 24 then return "Max Pump"
    else                        return "No Data"
    end
end

local function checkDemoMode()
    if demoMode then
        FuelValueL = 100*((system.getInputs( "P5" ) + 1.0)/2)
        FuelValueR = 100*((system.getInputs( "P6" ) + 1.0)/2)
        RPMValueL = math.floor((((system.getInputs( "P4" ) + 1.0)/2)*150) * 1000)
        RPMValueR = math.floor((((system.getInputs( "P2" ) + 1.0)/2)*150) * 1000)
        EGTValueL = 1000*((system.getInputs( "P7" ) + 1.0)/2)
        EGTValueR = 1000*((system.getInputs( "P7" ) + 1.0)/2)
        EcuBattValueL = 100*((system.getInputs( "P8" ) + 1.0)/2)
        EcuBattValueR = 100*((system.getInputs( "P8" ) + 1.0)/2)
        ECUVValueL = 12.6*((system.getInputs( "P8" ) + 1.0)/2)
        ECUVValueR = 12.6*((system.getInputs( "P8" ) + 1.0)/2)
        StatusCodeL = system.getInputs( "SB" )
        StatusCodeR = system.getInputs( "SC" )

        if StatusCodeL == 0 then
            StatusCodeL = 62
            MessageCodeL = 22
        end
        if StatusCodeR == 0 then
            StatusCodeR = 62
            MessageCodeR = 23
        end
        
        if StatusCodeL == 1 then
            StatusCodeL = 56
            MessageCodeL = 9
        end
        if StatusCodeL == -1 then
            StatusCodeL = 10
            MessageCodeL = 13
        end

        if StatusCodeR == 1 then
            StatusCodeR = 56
            MessageCodeR = 9
        end
        if StatusCodeR == -1 then
            StatusCodeR = 10
            MessageCodeR = 13
        end
    end
end

local function checkFuelAlarmFlags()
    if(StatusCodeL == 56 and FuelValueL > fuelAlarmL) then fuelAlarmArmedL = true end
    if(StatusCodeR == 56 and FuelValueR > fuelAlarmR) then fuelAlarmArmedR = true end
    if(StatusCodeL == 10  or MessageCodeL == 13) then
        fuelAlarmArmedL = false
        fuelAlarmPlayedL = false
        resetDoneL = false
        flameOutResetL = false

    end
    if(StatusCodeR == 10 or MessageCodeR == 13) then
        fuelAlarmArmedR = false
        fuelAlarmPlayedR = false
        resetDoneR = false
        flameOutResetR = false
    end
end

local function checkFuelAlarm()
    if (fuelAlarmL ~= 0 and FuelValueL ~= -1) then 
        if(fuelAlarmArmedL and FuelValueL <= fuelAlarmL) then
            if fuelAlarmRepeat == 0 and fuelAlarmPlayedL then 
                --Prevent further repetitions
            elseif system.getTimeCounter() - lastAlarmL > fuelAlarmRepeat then
                if fuelAlarmFile ~= "" then system.playFile(fuelAlarmFile,AUDIO_QUEUE) end
                if alarmVoice then system.playNumber(FuelValueL,0,"%") end
                system.messageBox("Warning: LOW FUEL LEFT TANK",3)
                lastAlarmL = system.getTimeCounter()
                fuelAlarmPlayedL = true
            end
        end
    end
    if (fuelAlarmR ~= 0 and FuelValueR ~= -1) then 
        if(fuelAlarmArmedR and FuelValueR <= fuelAlarmR) then
            if fuelAlarmRepeat == 0 and fuelAlarmPlayedR then 
                --Prevent further repetitions
            elseif system.getTimeCounter() - lastAlarmR > fuelAlarmRepeat then
                if fuelAlarmFile ~= "" then system.playFile(fuelAlarmFile,AUDIO_QUEUE) end
                if alarmVoice then system.playNumber(FuelValueL,0,"%") end
                system.messageBox("Warning: LOW FUEL RIGHT TANK",3)
                lastAlarmR = system.getTimeCounter()
                fuelAlarmPlayedR = true
            end
        end
    end
end

local function checkReminderAlert()
    local showMsg = false
    if(StatusCodeL == 56 and resetReminder == 1) then
        if (resetDoneL == false and FuelValueL < 95) then
            showMsg = true
            if resetReminderFile ~= "" then system.playFile(resetReminderFile,AUDIO_QUEUE) end
            resetDoneL = true
        else
            resetDoneL = true
        end
    end
    if(StatusCodeR == 56 and resetReminder == 1) then
        if (resetDoneR == false and FuelValueR < 95) then
            showMsg = true
            if resetReminderFile ~= "" then system.playFile(resetReminderFile,AUDIO_QUEUE) end
            resetDoneR = true
        else
            resetDoneR = true
        end
    end
    if showMsg then
        system.messageBox("Reset fuel consumption!",5)
    end
end

local function flameOutAlarm()
    local t_hold = (inputThrottlePos/100)
    local inputCtrl
    if inputThrottle == 1 then
        inputCtrl = "P1"
    elseif inputThrottle == 2 then
        inputCtrl = "P2"
    elseif inputThrottle == 3 then
        inputCtrl = "P3"
    elseif inputThrottle == 4 then
        inputCtrl = "P4"
    end
    
    if flameOutCodes[MessageCodeL] then
        flameOutL = true
    end
    if flameOutCodes[MessageCodeR] then
        flameOutR = true
    end
    if flameOutL or flameOutR then
        --Alert flameout
        if t_hold < 0 then
            if system.getInputs(inputCtrl) > t_hold and flameOutTC_Enabled == false then
                system.setControl(1,1,0,0)
            elseif system.getInputs(inputCtrl) <= t_hold then
                system.setControl(1,-1,0,0)
            end
        else
            if system.getInputs(inputCtrl) < t_hold and flameOutTC_Enabled == false then
                system.setControl(1,1,0,0)
            elseif system.getInputs(inputCtrl) >= t_hold then
                system.setControl(1,-1,0,0)
            end
        end
        flameOutTC_Enabled = true
    end
    if flameOutTC_Enabled then
        if system.getTimeCounter() - lastFlameOutRepeat > flameOutRepeat and flameOutRepeat > 0 then
            if flameOutL then
                system.messageBox("Left engine flameout!",2)
                if flameOutFileL ~= "" then system.playFile(flameOutFileL,AUDIO_QUEUE) end
                --print("Left Flameout")
            elseif flameOutR then
                system.messageBox("Right engine flameout!",2)
                if flameOutFileR ~= "" then system.playFile(flameOutFileR,AUDIO_QUEUE) end
                --print("Right Flameout")
            end
            lastFlameOutRepeat = system.getTimeCounter()
        end
    end

end

local function resetFlameOutStatus()
    if (StatusCodeL == 56 or MessageCodeL == 13) and flameOutResetL == false then
        flameOutL = false
        flameOutResetL = true
    end
    if (StatusCodeR == 56 or MessageCodeR == 13) and flameOutResetR == false then
        flameOutR = false
        flameOutResetR = true
    end
    if flameOutL == false and flameOutR == false then
        system.setControl(1,-1,0,0)
        flameOutTC_Enabled = false
    end
end

local function initSettingsForm(formID)

    sensorsAvailable = {}
    local available = system.getSensors();
    local list={}

    local curIndexL=-1
    local curIndexR=-1
    for index,sensor in ipairs(available) do
        if(sensor.param == 0) then
            list[#list+1] = sensor.label
            sensorsAvailable[#sensorsAvailable+1] = sensor
            if(sensor.id==sensorIdL ) then
                curIndexL=#sensorsAvailable
            end
            if(sensor.id==sensorIdR ) then
                curIndexR=#sensorsAvailable
            end
        end
    end


    -- sensor select
    form.addRow(2)
    form.addLabel({label="Select left sensor",width=140})
    form.addSelectbox (list, curIndexL,true,sensorChangedL,{width=170})

    form.addRow(2)
    form.addLabel({label="Select right sensor",width=140})
    form.addSelectbox (list, curIndexR,true,sensorChangedR,{width=170})
    
    form.addSpacer(100,10)
    form.addLabel({label="Alarms",font=FONT_BOLD})
    form.addRow(3)
    form.addLabel({label="Fuel warning  [%]", width=130})
    form.addLabel({label="(0=Disabled)", width=80, font=FONT_MINI})
    form.addIntbox(fuelAlarmL,0,99,30,0,1,fuelAlarmChanged)
    form.addRow(2)
    form.addLabel({label="    File",width=190})
    form.addAudioFilebox(fuelAlarmFile or "",fuelAlarmFileChanged)
    form.addRow(2)
    form.addLabel({label="    Repeat every [s]", width=190})
    form.addIntbox(fuelAlarmRepeat/1000,0,60,10,0,1,fuelAlarmRepeatChanged,{width=120})
    form.addRow(2)
    form.addLabel({label="    Announce value by voice", width=240})
    form.addSelectbox (booleanSelect, alarmVoice,false,alarmVoiceValueChanged)
    form.addRow(2)
    form.addLabel({label="Fuel consumption reset reminder", width=240})
    form.addSelectbox (booleanSelect, resetReminder,false,resetReminderChanged)
    form.addRow(2)
    form.addLabel({label="    File",width=190})
    form.addAudioFilebox(resetReminderFile or "",resetReminderFileChanged)

    
    --form.addSpacer(100,10)
    --form.addLabel({label="Engine Flameout Alarm",font=FONT_BOLD})


    form.addRow(2)
    form.addLabel({label="L engine flameout file",width=190})
    form.addAudioFilebox(flameOutFileL or "",flameOutFileLChanged)
    form.addRow(2)
    form.addLabel({label="R engine flameout file",width=190})
    form.addAudioFilebox(flameOutFileR or "",flameOutFileRChanged)
    form.addRow(2)
    form.addLabel({label="    Repeat every [s]", width=190})
    form.addIntbox(flameOutRepeat/1000,0,10,3,0,1,flameOutRepeatChanged,{width=120})

    form.addSpacer(100,10)
    form.addLabel({label="Engine Flameout Throttle Cut",font=FONT_BOLD})
    form.addRow(2)
    form.addLabel({label="Throttle input control", width=170})
    form.addSelectbox(inputControls,inputThrottle, false,inputThrottleChanged,{width=140})
    form.addRow(2)
    form.addLabel({label="Throttle regain position", width=210})
    form.addIntbox(inputThrottlePos,-100,100,-95,0,1,inputThrottlePosChanged,{width=100})
    
    --form.addInputbox(switch, true, function(value) print(value) end)
    --form.addRow(1)
    --form.addLabel({label="- Make shure input control is selected as PROPORTIONAL", font=FONT_MINI})
    
    form.addLabel({label="  To enable:", font=FONT_MINI})
    form.addRow(1)
    form.addLabel({label="- Set Throttle Cut SW to 'User Applications/FSW'", font=FONT_MINI})
    form.addRow(1)
    form.addLabel({label="  and desired output value in: 'Menu > Advanced -", font=FONT_MINI})
    form.addRow(1)
    form.addLabel({label="  Properties > Other Model Options'", font=FONT_MINI})
    form.addRow(1)
    form.addLabel({label="- In case of engine flameout Throttle Cut will be engaged,", font=FONT_MINI})
    form.addRow(1)
    form.addLabel({label="  move stick immediately to position set above to regain ", font=FONT_MINI})
    form.addRow(1)
    form.addLabel({label="  throttle control", font=FONT_MINI})
    form.addRow(1)
    form.addLabel({label="- Always make sure everything works as expected", font=FONT_MINI})
    form.addRow(1)
    form.addLabel({label="  before actually flying your model.", font=FONT_MINI})
    form.addRow(1)
    form.addLabel({label="- Jet Central is not in any way responsible for", font=FONT_MINI})
    form.addRow(1)
    form.addLabel({label="  any injuries and/or damage while using this feature.", font=FONT_MINI})
    --form.addLabel({label="", font=FONT_MINI})
    
    


--[[     form.addSpacer(100,10)
    form.addLabel({label="Alternating display",font=FONT_BOLD})

    form.addRow(2)
    form.addLabel({label="Show RPM", width=190})
    form.addSelectbox (booleanSelect, alternateRPM,false,alternateRPMChanged)

    form.addRow(2)
    form.addLabel({label="Show EGT [°C]", width=190})
    form.addSelectbox (booleanSelect, alternateEGT,false,alternateEGTChanged)

    form.addRow(2)
    form.addLabel({label="Show ECU batt [V]", width=190})
    form.addSelectbox (booleanSelect, alternateBattV,false,alternateBattVChanged)

    form.addRow(2)    
    form.addLabel({label="Show ECU batt [%]", width=190})
    form.addSelectbox (booleanSelect, alternateBatt,false,alternateBattChanged)

    form.addRow(2)
    form.addLabel({label="Change display every [s]", width=190})
    form.addIntbox(alternatingDelay/100,10,100,30,1,1,alternatingDelayChanged,{width=120})
 ]]
    --Demo Mode
    form.addSpacer(100,10)
    form.addRow(2)
    form.addLabel({label="Demo mode enabled", width=274})
    demoModeCtrl = form.addCheckbox(demoMode,demoModeChanged)


    collectgarbage()
end

local function printFullDisplay(width, height)
    local lbl, val

    lcd.drawImage(0, 0, jcLogo)

    lcd.setColor(0x22,0x2B,0x00,255)
    lbl = decodeStatus(StatusCodeL)
    lcd.drawText(62 - (lcd.getTextWidth(FONT_NORMAL,lbl))/2,121 ,lbl,FONT_NORMAL)
    lbl = decodeMessage(MessageCodeL)
    lcd.drawText(62 - (lcd.getTextWidth(FONT_MINI,lbl))/2,138 ,lbl,FONT_MINI)

    lbl = decodeStatus(StatusCodeR)
    lcd.drawText(260 - (lcd.getTextWidth(FONT_NORMAL,lbl))/2,121 ,lbl,FONT_NORMAL)
    lbl = decodeMessage(MessageCodeR)
    lcd.drawText(260 - (lcd.getTextWidth(FONT_MINI,lbl))/2,138 ,lbl,FONT_MINI)


    lcd.setColor(0xFF,0x55,0x55,255)
    drawShape(159, (56), alarmHandle, math.rad(220+fuelAlarmL*1.2))
    drawShape(159, (56), alarmHandle, math.rad(140-fuelAlarmR*1.2))


    lcd.setColor(240,240,240,255)

    --Fuel Gauge  
    val=FuelValueL
    lbl = string.format("%d%%", val)
    if val == -1 then
        lbl = "_"
        val=-10
    end
    drawShape(159, (56), largeHandle, math.rad(220+val*1.2))
    lcd.drawText((160 - (lcd.getTextWidth(FONT_BOLD,lbl))/2),72 ,lbl,FONT_BOLD)

    val=FuelValueR
    lbl = string.format("%d%%", val)
    if val == -1 then
        lbl = "_"
        val=-10
    end
    drawShape(159, (56), largeHandle, math.rad(140-val*1.2))
    lcd.drawText((160 - (lcd.getTextWidth(FONT_BOLD,lbl))/2),86 ,lbl,FONT_BOLD)

    --RPM Gauge
    val = RPMValueL
    if val == -1 then
        lbl = "_"
        val=-20
    else
        val=math.floor(RPMValueL/1000)
        lbl = string.format("%d", val)
    end
    drawShape(56, (63), mediumHandle, math.rad(220+val*0.8))
    lcd.drawText((57 - (lcd.getTextWidth(FONT_NORMAL,lbl))/2),74 ,lbl,FONT_NORMAL)

    val = RPMValueR
    if val == -1 then
        lbl = "_"
        val=-20
    else
        val=math.floor(RPMValueR/1000)
        lbl = string.format("%d", val)
    end
    drawShape(56, (63), mediumHandle, math.rad(140-val*0.8))
    lcd.drawText((57 - (lcd.getTextWidth(FONT_NORMAL,lbl))/2),88 ,lbl,FONT_NORMAL)

    --EGT Gauge
    val=EGTValueL
    lbl = string.format("%d", val)
    if val == -1 then
        lbl = "_"
        val=-160
    end
    drawShape(242, 78, smallHandle, math.rad(220 + val/10))
    lcd.drawText((243 - (lcd.getTextWidth(FONT_MINI,lbl))/2), 85, lbl, FONT_MINI)

    val=EGTValueR
    lbl = string.format("%d", val)
    if val == -1 then
        lbl = "_"
        val=-160
    end      
    drawShape(242, 78, smallHandle, math.rad(140 - val/10))
    lcd.drawText((243 - (lcd.getTextWidth(FONT_MINI,lbl))/2), 95, lbl, FONT_MINI)

    --Batt Gauge
    val=EcuBattValueL
    lbl = string.format("%.1fv", ECUVValueL)
    if val == -1 then
        lbl = "_"
        val=-12
    end
    drawShape(284, 32, smallHandle, math.rad(220+val*1.2))
    lcd.drawText((287 - (lcd.getTextWidth(FONT_MINI,lbl))/2), 37, lbl, FONT_MINI)

    val=EcuBattValueR
    lbl = string.format("%.1fv", ECUVValueR)
    if val == -1 then
        lbl = "_"
        val=-12
    end
    drawShape(284, 32, smallHandle, math.rad(140-val*1.2))
    lcd.drawText((287 - (lcd.getTextWidth(FONT_MINI,lbl))/2), 47, lbl, FONT_MINI)

    collectgarbage()

end

local function init()
    -- sensor id
    sensorIdL = system.pLoad("SensorIdL",0)
    sensorIdR = system.pLoad("SensorIdR",0)

    if sensorIdL == 0 then
        local available = system.getSensors()
        for index,sensor in ipairs(available) do
            if((sensor.id & 0xFFFFFF) == 0x4CA40C) then -- Fill default sensor ID
                sensorIdL = sensor.id
                break
            end
        end
    end

    if sensorIdR == 0 then
        local available = system.getSensors()
        for index,sensor in ipairs(available) do
            if((sensor.id & 0xFFFFFF) == 0x52A40C) then -- Fill default sensor ID
                sensorIdR = sensor.id
                break
            end
        end
    end

    --Load Settings
    inputThrottle = system.pLoad("inputThrottle",4)
    inputThrottlePos = system.pLoad("inputThrottlePos",-95)
    flameOutFileL = system.pLoad("flameOutFileL","")
    flameOutFileR = system.pLoad("flameOutFileR","")
    flameOutRepeat = system.pLoad("flameOutRepeat",3000)
    fuelAlarmL = system.pLoad("FuelAlarm",30)
    fuelAlarmR = system.pLoad("FuelAlarm",30)
    fuelAlarmFile = system.pLoad("FuelAlarmFile","")
    fuelAlarmRepeat = system.pLoad("FuelAlarmRepeat",10000)
    demoMode = system.pLoad("DemoMode",0)
    if demoMode == 0 then demoMode = false else demoMode = true end

    alarmVoice = system.pLoad("AlarmVoice", 1)
    resetReminder = system.pLoad("ResetReminder",1)
    resetReminderFile = system.pLoad("ResetReminderFile","")

    system.registerTelemetry( 1, "Jet Central Twin HDT", 4, printFullDisplay)
    system.registerForm(1,MENU_TELEMETRY,"Jet Central Twin HDT",initSettingsForm,nil,nil)
    system.registerControl(1,"Flameout Switch","FSW")
    system.setControl(1,-1,0,0)

    jcLogo = lcd.loadImage("Apps/JetCentral/CFTwin.png")
    collectgarbage()
end

local function loop()
    local sensor

    -- RPM
    sensor = system.getSensorByID(sensorIdL,1)
    if( sensor and sensor.valid ) then RPMValueL = sensor.value else RPMValueL = -1 end
    sensor = system.getSensorByID(sensorIdR,1)
    if( sensor and sensor.valid ) then RPMValueR = sensor.value else RPMValueR = -1 end

    -- EGT
    sensor = system.getSensorByID(sensorIdL,2)
    if( sensor and sensor.valid ) then EGTValueL = sensor.value else EGTValueL = -1 end
    sensor = system.getSensorByID(sensorIdR,2)
    if( sensor and sensor.valid ) then EGTValueR = sensor.value else EGTValueR = -1 end

    -- EcuV
    sensor = system.getSensorByID(sensorIdL,3)
    if( sensor and sensor.valid ) then ECUVValueL = sensor.value else ECUVValueL = -1 end
    sensor = system.getSensorByID(sensorIdR,3)
    if( sensor and sensor.valid ) then ECUVValueR = sensor.value else ECUVValueR = -1 end

    -- EcuBatt
    sensor = system.getSensorByID(sensorIdL,5)
    if( sensor and sensor.valid ) then EcuBattValueL = sensor.value else EcuBattValueL = -1 end
    sensor = system.getSensorByID(sensorIdR,5)
    if( sensor and sensor.valid ) then EcuBattValueR = sensor.value else EcuBattValueR = -1 end

    -- Fuel
    sensor = system.getSensorByID(sensorIdL,6)
    if( sensor and sensor.valid ) then FuelValueL = sensor.value else FuelValueL = -1 end
    sensor = system.getSensorByID(sensorIdR,6)
    if( sensor and sensor.valid ) then FuelValueR = sensor.value else FuelValueR = -1 end

    -- Status
    sensor = system.getSensorByID(sensorIdL,8)
    if( sensor and sensor.valid ) then StatusCodeL = sensor.value else StatusCodeL = 0 end
    sensor = system.getSensorByID(sensorIdR,8)
    if( sensor and sensor.valid ) then StatusCodeR = sensor.value else StatusCodeR = 0 end

    -- Message
    sensor = system.getSensorByID(sensorIdL,9)
    if( sensor and sensor.valid ) then MessageCodeL = sensor.value else MessageCodeL = 0 end
    sensor = system.getSensorByID(sensorIdR,9)
    if( sensor and sensor.valid ) then MessageCodeR = sensor.value else MessageCodeR = 0 end

    checkDemoMode()
    checkFuelAlarmFlags()
    checkReminderAlert()
    resetFlameOutStatus()
    checkFuelAlarm()
    flameOutAlarm()

    collectgarbage()
end

return {init=init, loop=loop, author="DLPWings", version="1.00",name="Jet Central Twin HDT"}