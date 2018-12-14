<CsoundSynthesizer>
<CsOptions>
-odac -iadc -b128 -B512 -m0d -Ma
</CsOptions>
<CsInstruments>
sr      = 44100
ksmps  	= 16
0dbfs	= 1
nchnls 	= 2

    giBufferLen           = 131072 ; Almost 3 seconds
    giRingBuff              ftgen   0, 0, giBufferLen+1, 2, 0                             ; create empty buffer for live follow mode
    giForwardsBuff          ftgen   0, 0, giBufferLen+1, 2, 0
    giBackwardsBuff         ftgen   0, 0, giBufferLen+1, 2, 0
    giFreezeBuff            ftgen   0, 0, (giBufferLen*2)+1, 2, 0

instr 10
	aL, aR ins
    ain = aL+aR

    outs aL+aR,aR+aL
endin


opcode ducking, a, aak

    ainput, andx, kducktime xin

    kenv init 1
    kidx = 0

    while (kidx < ksmps) do
        kval = andx[kidx]
        if (kval > (1-kducktime)) then
            kenv = ((1 - kval) * (1/kducktime))
        endif
        if (kval > 0) && (kval < kducktime) then
            kenv = (kval * (1/kducktime))
        endif
        kidx += 1
    od

    ;printk2 kenv

    xout ainput*kenv
endop



instr 1
	aL, aR ins
    ain = aL+aR

    kfader1 ctrl7 7, 16, 0, 1

    kstutterTrig init 0
    kstop init 0
    kreverse init 1

    initc7 7, 32, 0
    kstutterTrig ctrl7 7, 32, 0, 1
    kstutterTrig metro 0.2

    kstop ctrl7 7, 48, 0, 1
    kreverse ctrl7 7, 64, 1, -1

    ; Speed control
    initc7 7, 0, 0.3
    kfader4 ctrl7 7, 0, 0, 1
    ; Speed modifier
    initc7 7, 1, 0.1
    kfader5 ctrl7 7, 1, 1, 11
    kspeedMod = int(kfader5)

    ; Speed quantisation modes:
    ; 0: Free
    ; 1: Harmonic 
    ; 2: Fifths and Ocatves
    ; 3: Chromatic

    kSpeedQuantizeMode init 2

    if kSpeedQuantizeMode == 0 then 
        kspeed = (kfader4 * 2)
    elseif kSpeedQuantizeMode == 1 then 
        kharmonicScale[] fillarray 0.125, 0.25, 0.5, 0.75, 1, 1.25, 1.5, 1.75, 2, 2.25, 2.5, 2.75,3 
        kharmonicIdx = int(kfader4 * 12.99)
        kspeed = kharmonicScale[kharmonicIdx]  
    elseif kSpeedQuantizeMode == 2 then 
        kfifthScale[] fillarray 0.25, 0.333333333333, 0.5, 0.6666666667, 1, 1.5, 2, 3, 4 
        kspeedIdx = int(kfader4 * 8.99)
        kspeed = kfifthScale[kspeedIdx]  
    elseif kSpeedQuantizeMode == 3 then 
        kchromaScale[] fillarray 1, 1.05946309436, 1.12246204831, 1.18920711501, 1.2599210499, 1.33483985417, 1.41421356238, 1.49830707688, 1.58740105198, 1.68179283052, 1.78179743629, 1.88774862538, 2.00000000002
        kchromaIdx = int(kfader4 * 12.99)
        kspeed = kchromaScale[kchromaIdx]
    endif 

    kspeed *= kreverse
    kspeed *= kspeedMod
    printk2 kspeed
    kspeed port kspeed, 0.05

    ;kstutterTrig metro 1
 
    if trigger(kstutterTrig, 0.5, 0) == 1 then 
        printks "Stutter!\n", 0
        kstopPlayback = 0
        reinit STUTTER
    endif

 STUTTER:
    krecIdx init 0
    kstartPlayback init 0
    ; Delay mode:
    ; 0: instant
    ; 1: loop mode
    kdelayMode = 0

    ; Non click ramp
    kenv linseg 0, 0.001, 1
    ain *= kenv

    initc7 7, 17, 0.5
    kwindowSize ctrl7 7, 17, 0.001, 0.08    
    kwindowSize port kwindowSize, 0.01
    ;kwindowSize = 0.05

    ktranspose = p4
    kspeed *= ktranspose
    kwindowSize *= ktranspose

    ktempoDivisions[] fillarray 0.125, 0.1666666675, 0.25, 0.33333333333, 0.5, 0.6666666667, 0.75, 1
    kspeedModifiers[] fillarray 0.25, 0.333333333, 0.5, 0.6666666667, 0.75, 1, 1.25, 1.5, 1.75, 2, 2.25, 2.5, 2.75, 3
    kmetro metro 0.2
    ;ktempo_randIdx = 7
    ktempo_randIdx trandom kmetro, 0, 8.99

    kmetro2 metro 3
    kspeed_randIdx = 5;trandom kmetro2, 0, 13.99

    ksizeDivision = ktempoDivisions[ktempo_randIdx]
    ktempoDivision = kspeedModifiers[kspeed_randIdx] 

    kwindowSize *= ksizeDivision
    kspeed *= ktempoDivision

    kwindowSizeRaw = (kwindowSize*(giBufferLen-1))-ksmps
    ;printk2 kwindowSizeRaw

    kidx = 0
    while (kidx < ksmps) do
        kval = ain[kidx]
        if krecIdx < giBufferLen-1 then 
            krecIdx += 1
            tablew kval, krecIdx, giForwardsBuff, 0
            ;tablegpw giForwardsBuff
            ;krecIdx += 1
        endif
        ; Loopmode stutter playback
        if krecIdx >= kwindowSizeRaw && kdelayMode == 1 then 
            kstartPlayback = 1
        endif
        kidx += 1
    od

    ; Instant stutter playback
    if krecIdx > ksmps && kdelayMode == 0 then 
        kstartPlayback = 1
    endif

    krate = 1 / (giBufferLen / sr) 
    andx phasor (a(krate) / a(kwindowSize)) * a(kspeed)
    andxRaw = andx * a(kwindowSizeRaw)

    if trigger(kstop, 0.5, 0) == 1 then 
        kstopPlayback += 1
        kstopPlayback = kstopPlayback % 2
    endif

    if kstartPlayback == 1 && kstopPlayback == 0 then 
 ;       aout table3 andx, giForwardsBuff, 0, ksmps, 1
        aout lposcil3 1, kspeed, 0, kwindowSizeRaw, giForwardsBuff
    else
        aout = 0
    endif 

    kducktime = 0.1 ; 0 - 1 
    ; Duck loop points
    aout ducking aout, andx, kducktime

    a0 = aout;0
    outs aout, aout

endin

/*
instr 3
	aL, aR ins
    ain = aL 

    kfader1 ctrl7 7, 41, 0, 1

    kstutterTrig init 0
    kstop init 0
    kreverse init 1
    kstutterPoint init 0

    kstutterTrig ctrl7 7, 89, 0, 1
    kstop ctrl7 7, 90, 0, 1
    kreverse ctrl7 7, 91, 1, -1

    ; Speed control
    kfader4 ctrl7 7, 44, 0, 1
    ; Speed modifier
    kfader5 ctrl7 7, 45, 1, 11
    kspeedMod = int(kfader5)

    krecIdx init 0
    krecIdx   tablewa giRingBuff, aL/0dbfs, 0                                ; write audio a1 to table 
    krecIdx   = (krecIdx > (giBufferLen-1) ? 0 : krecIdx)       ; reset kstart when table is full
        tablegpw giRingBuff
    krecIdx += 1

    kstutterTrig metro 1

    if changed(kstutterTrig) == 1 then 
        tablecopy giBackwardsBuff, giRingBuff
        kstutterPoint = krecIdx
        ; MAKE A NEW TABLE where the first part is giBackwardsBuff
        ; and the second part is giForwardsBuff
        ; giFreezeBuff is double length buffer

        ; if playback idx is equal or larger than kstutterPoint, then change playbackbuffer 
        printks "STUTTER!\n", 0
        reinit RESTART
    endif

    ; Speed quantisation modes:
    ; 0: Free
    ; 1: Integer 
    ; 2: Fifths and Ocatves
    ; 3: Chromatic

    kSpeedQuantizeMode init 1
    kspeed init 1

    if kSpeedQuantizeMode == 0 then 
        kspeed = (kfader4 * 2)
    elseif kSpeedQuantizeMode == 1 then 
        kharmonicScale[] fillarray 0.125, 0.25, 0.5, 0.75, 1, 1.25, 1.5, 1.75, 2, 2.25, 2.5, 2.75,3 
        kharmonicIdx = int(kfader4 * 12.99)
        kspeed = kharmonicScale[kharmonicIdx]  
    elseif kSpeedQuantizeMode == 2 then 
        kfifthScale[] fillarray 0.25, 0.333333333333, 0.5, 0.6666666667, 1, 1.5, 2, 3, 4 
        kspeedIdx = int(kfader4 * 8.99)
        kspeed = kfifthScale[kspeedIdx]  
    elseif kSpeedQuantizeMode == 3 then 
        kchromaScale[] fillarray 1, 1.05946309436, 1.12246204831, 1.18920711501, 1.2599210499, 1.33483985417, 1.41421356238, 1.49830707688, 1.58740105198, 1.68179283052, 1.78179743629, 1.88774862538, 2.00000000002
        kchromaIdx = int(kfader4 * 12.99)
        kspeed = kchromaScale[kchromaIdx]
    endif 

    kspeed *= kreverse
    kspeed *= kspeedMod
    ;printk2 kspeed
    kspeed port kspeed, 0.1

    kwindowSize ctrl7 7, 43, 0.003, 1    
    kwindowSize port kwindowSize, 0.1
    awindowSize interp kwindowSize
    awindowSizeRaw = awindowSize*(giBufferLen-1)
    kwindowSizeRaw = kwindowSize*(giBufferLen-1)
    

    krate = 1 / (giBufferLen / sr) 

RESTART:

    kidx = 0
    while (kidx < ksmps) do
        kval = ain[kidx]
        if krecIdx < giBufferLen-1 then 
            tablew kval, krecIdx, giForwardsBuff, 0
            tablegpw giForwardsBuff
            krecIdx += 1
        endif
        ; Loopmode stutter playback
        if krecIdx >= kwindowSizeRaw && kdelayMode == 1 then 
            kstartPlayback = 1
        endif
        kidx += 1
    od


    ioffset = i(krecIdx)
    andx phasor (a(krate)/awindowSize)*a(kspeed)
    andx *= giBufferLen * awindowSize

    aout table3 (andx-awindowSizeRaw), giForwardsBuff, 0, ioffset, 1

    kfader7 ctrl7 7, 47, 0, 1
    kfader8 ctrl7 7, 48, 0, 1

    a0 = 0
    outs a0, aout + (aoutFifth*kfader7) + (aoutOct*kfader8)

endin
*/

; BACKWARDS STUTTER

/*
instr 2
	aL, aR ins

    kfader1 ctrl7 7, 41, 0, 1

    kstutterTrig init 0
    kstop init 0
    kreverse init 1

    kstutterTrig ctrl7 7, 89, 0, 1
    kstop ctrl7 7, 90, 0, 1
    kreverse ctrl7 7, 91, 1, -1

    ; Speed control
    kfader4 ctrl7 7, 44, 0, 1
    ; Speed modifier
    kfader5 ctrl7 7, 45, 1, 11
    kspeedMod = int(kfader5)

    krecIdx init 0
    krecIdx   tablewa giRingBuff, aL/0dbfs, 0                                ; write audio a1 to table 
    krecIdx   = (krecIdx > (giBufferLen-1) ? 0 : krecIdx)       ; reset kstart when table is full
        tablegpw giRingBuff
    krecIdx += 1

    kstutterTrig metro 1

    if changed(kstutterTrig) == 1 then 
        tablecopy giStutterBuff, giRingBuff
        printks "STUTTER!\n", 0
        reinit RESTART
    endif

    ; Speed quantisation modes:
    ; 0: Free
    ; 1: Integer 
    ; 2: Fifths and Ocatves
    ; 3: Chromatic

    kSpeedQuantizeMode init 1
    kspeed init 1

    if kSpeedQuantizeMode == 0 then 
        kspeed = (kfader4 * 2)
    elseif kSpeedQuantizeMode == 1 then 
        kharmonicScale[] fillarray 0.125, 0.25, 0.5, 0.75, 1, 1.25, 1.5, 1.75, 2, 2.25, 2.5, 2.75,3 
        kharmonicIdx = int(kfader4 * 12.99)
        kspeed = kharmonicScale[kharmonicIdx]  
    elseif kSpeedQuantizeMode == 2 then 
        kfifthScale[] fillarray 0.25, 0.333333333333, 0.5, 0.6666666667, 1, 1.5, 2, 3, 4 
        kspeedIdx = int(kfader4 * 8.99)
        kspeed = kfifthScale[kspeedIdx]  
    elseif kSpeedQuantizeMode == 3 then 
        kchromaScale[] fillarray 1, 1.05946309436, 1.12246204831, 1.18920711501, 1.2599210499, 1.33483985417, 1.41421356238, 1.49830707688, 1.58740105198, 1.68179283052, 1.78179743629, 1.88774862538, 2.00000000002
        kchromaIdx = int(kfader4 * 12.99)
        kspeed = kchromaScale[kchromaIdx]
    endif 

    kspeed *= kreverse
    kspeed *= kspeedMod
    ;printk2 kspeed
    kspeed port kspeed, 0.1

    kwindowSize ctrl7 7, 43, 0.003, 1    
    kwindowSize port kwindowSize, 0.1
    awindowSize interp kwindowSize
    awindowSizeRaw = awindowSize*(giBufferLen-1)

    krate = 1 / (giBufferLen / sr) 

RESTART:
    ioffset = i(krecIdx)
    andx phasor (a(krate)/awindowSize)*a(kspeed)
    andxFifth phasor (a(krate)/awindowSize)*a(kspeed)*1.5
    andxOct phasor (a(krate)/awindowSize)*a(kspeed)*2
 
    andx *= giBufferLen * awindowSize
    andxFifth *= giBufferLen * awindowSize
    andxOct *= giBufferLen * awindowSize

    aout table3 (andx-awindowSizeRaw), giStutterBuff, 0, ioffset, 1

    aoutFifth table3 (andxFifth-awindowSizeRaw), giStutterBuff, 0, ioffset, 1

    aoutOct table3 (andxOct-awindowSizeRaw), giStutterBuff, 0, ioffset, 1


    kfader7 ctrl7 7, 47, 0, 1
    kfader8 ctrl7 7, 48, 0, 1

    a0 = 0
    outs a0, aout + (aoutFifth*kfader7) + (aoutOct*kfader8)

endin

*/
</CsInstruments>
<CsScore>
i1 0 86400 1
;i10 0 86400
e
i1 0 86400 1.5
i1 0 86400 2



;i2 0 86400
</CsScore>
</CsoundSynthesizer>


