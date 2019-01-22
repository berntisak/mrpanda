<Cabbage>
form size(350,275), text("FreezeStutter"), guirefresh(32), pluginid("fspd")
button    bounds( 55, 15, 60, 25), fontcolour:0(50,50,50), fontcolour:1(255,205,205), colour:0(10,0,0), colour:1(150,0,0), text("Stutter","Stutter"), channel("Stutter"), latched(1)
button    bounds( 145, 15, 60, 25), fontcolour:0(50,50,50), fontcolour:1(255,205,205), colour:0(10,0,0), colour:1(150,0,0), text("RandPitch","RandPitch"), channel("RandPitch"), latched(1)
button    bounds( 235, 15, 60, 25), fontcolour:0(50,50,50), fontcolour:1(255,205,205), colour:0(10,0,0), colour:1(150,0,0), text("RandSize","RandSize"), channel("RandSpeed"), latched(1)


rslider   bounds( 15, 70, 80, 80), range(0.001, 0.3,0.1), channel("LoopSize"), text("Loop size")
rslider   bounds( 95, 70, 80, 80), range(0.0001, 1.0,0.01), channel("Ducktime"), text("Ducktime")
rslider   bounds( 180, 70, 80, 80), range(0.0, 1.0,0.35), channel("Speed"), text("Speed")
rslider   bounds( 265, 70, 80, 80), range(1.0, 11.0,1), channel("SpeedMod"), text("SpeedMod")


rslider   bounds( 95, 160, 80, 80), range(0.5, 10,2), channel("RandSpeedSpeed"), text("Random Pitch Freq")
rslider   bounds( 180, 160, 80, 80), range(0.5, 10,3), channel("RandTempoSpeed"), text("Random Size Freq")



</Cabbage>

<CsoundSynthesizer>
<CsOptions>
-odac -iadc -b128 -B512 -Ma ;-m0d -Ma
</CsOptions>
<CsInstruments>
sr      = 44100
ksmps  	= 16
0dbfs	= 1
nchnls 	= 2

    giBufferLen             = 131072 ; Almost 3 seconds
    giRingBuff              ftgen   0, 0, giBufferLen, 2, 0                             
    giFreezeBuff1           ftgen   0, 0, (giBufferLen*2), 2, 0
    giFreezeBuff2           ftgen   0, 0, (giBufferLen*2), 2, 0

    giTmpBuff               ftgen   0, 0, giBufferLen, 2, 0

    giWinSize = 4096
    giWin		ftgen	0, 0, giWinSize, 20, 9, 1		; grain envelope

opcode ducking, a, aak

    ainput, andx, kducktime xin

    kenv init 1
    kidx = 0
    kducktime *= 0.5
    kducktime limit kducktime, 0, 0.5

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

    xout ainput*kenv
endop


opcode Ringbufferer, k, ai 
    ain, ibuffer xin 

    ibuffLen = ftlen(ibuffer)

    krecIdx init 0
    krecIdx   tablewa ibuffer, ain/0dbfs, 0             ; write audio ain to table 
    krecIdx   = (krecIdx > (ibuffLen-1) ? 0 : krecIdx)    ; reset kstart when table is full
        tablegpw ibuffer

    krecIdx += 1

    xout krecIdx
endop

opcode Ringbufferer, k, aaii 
    ainL, ainR, iftableL, iftableR xin
    krecIdx Ringbufferer ainL, iftableL
    kunused Ringbufferer ainR, iftableR

    xout krecIdx
endop

opcode BufferRec, k, akki

    ain, krecording, koffset, ibuffer xin
    
    ibuffLen = ftlen(ibuffer)
    krecIdx init 0
    koffset init 0   
    ; Reset variables before new recording
    if trigger(krecording, 0.5, 0) == 1 then
        krecIdx = koffset
        printks "Recording to buffer %d at idx %d - totalt length: %d\n", 0, ibuffer, koffset, ibuffLen
    endif

    kidx = 0
    while (kidx < ksmps) do
        kval = ain[kidx]
        if krecIdx < ibuffLen-1 then 
            krecIdx += 1
            tablew kval, krecIdx, ibuffer, 0
        endif
        kidx += 1
    od

    xout krecIdx 
endop

opcode BufferPlay, a, ikkkkkkO

    ibuffer, kplaying, koffset, kloopSize, kducktime, kspeed, ktranspose, iphs xin

    kspeed *= ktranspose
    kloopSize *= ktranspose
    ibuffLen = ftlen(ibuffer)
    koffset init 0.5
    kloopSize init 1

    kloopSizeScaled = (kloopSize*(ibuffLen-1)) 
    
    krate = 1 / (ibuffLen / sr) 

    aloopSize interp kloopSize
    aloopSizeScaled interp kloopSizeScaled
    koffsetScaled = koffset * (ibuffLen-1)

    andx phasor (a(krate) / aloopSize) * a(kspeed), 0
    andxScaled = andx * aloopSizeScaled

    if kplaying == 1 then 
        ;aout table3 (andxScaled-ksmps) + klocal_off, ibuffer, 0, ksmps, 1
        ;aout table3 andxScaled-a(koffset), ibuffer, 0, ksmps, 1

        kstartPoint = koffsetScaled-(kloopSizeScaled*0.5)
        kendPoint = koffsetScaled+(kloopSizeScaled*0.5)

        /*
        if trigger(kplaying, 0.5, 0) == 1 then 
            reinit PLAYBACK
        endif

        PLAYBACK:
        iphs = i(koffset) - (i(kloopSize)*0.5)
        */
        ;iphs = 0
        aout lposcil3 1, kspeed, kstartPoint, kendPoint, ibuffer        
    else 
        aout = 0
    endif

    aout ducking aout, andx, kducktime
;    aenv table3 andx*giWinSize, giWin
;    aout *= aenv

    xout aout

endop 

gkStutter = 0
gkspeed = 1
gkloopSizeMod = 1

instr 1

	aL, aR ins
    ain = aL+aR

    kplay init 0
    kswitchBuffer init 0

    ; Start the Ringbuffererer
    kringIdx Ringbufferer ain, giRingBuff

    ;kstutter ctrl7 1, 20, 0, 1
    ;initc7 1, 20, 0
    ;printk2 kstutter
    kstutter chnget "Stutter"

    ; After hitting stutter, do the following:
    if trigger(kstutter, 0.5, 0) == 1 then 
        ; 1. copy Ringbuffer to FreezeBuff
        ; tablecopy giFreezeBuff, giRingBuff
        if kswitchBuffer == 0 then 
            giFreezeBuff = giFreezeBuff1
        else
            giFreezeBuff = giFreezeBuff2
        endif
        
        kswitchBuffer += 1
        kswitchBuffer = kswitchBuffer % 2

        ; A manual tablecopy instead which copies from ringBuffIdx 
        ; to idx=0 in new table
        ; Could this be made into an opcode instead or optimized in a way?

        kcopyToIdx = giBufferLen-1
        kcopyFromIdx = kringIdx ; Should wrap around here
        kfromArr[] init giBufferLen
        ktoArr[] init giBufferLen

        ;printks "Start copying...at %d\n", 0, kringIdx

        copyf2array kfromArr, giRingBuff 
        while (kcopyToIdx >= 0) do
            ;printks "Copying %f from idx %d to idx %d\n", 0, kfromArr[kcopyFromIdx], kcopyFromIdx, kcopyToIdx
            ktoArr[kcopyToIdx] = kfromArr[kcopyFromIdx]
            kcopyToIdx -= 1
            kcopyFromIdx = kcopyFromIdx > 0 ? kcopyFromIdx-1 : giBufferLen-1
 ;           printk2 kcopyFromIdx
        od
        copya2ftab ktoArr, giFreezeBuff

        ; 2. set playing to ON
        kplay = 1
    endif

    ; 3. start recording to FreezeBuff with offset 
    ; set to recIdx outputted from Ringbuffer 
    kstartRec = kstutter
    krecOffset = giBufferLen-1
    krecIdx BufferRec ain, kstartRec, krecOffset, giFreezeBuff  

    ; ALTERNATIVE PLAYBACK - WAIT UNTIL END OF BUFF RECORDING OR LOOPSIZE

    ;kplay = krecIdx < (giBufferLen*2)-1 ? 0 : 1
    ;printk2 kplay
    ;kstartRec = kplay == 1 ? 0 : kstartRec

    ;kloopSize ctrl7 1, 10, 0.001, 0.5   
    ;initc7 1, 10, 0.1
    kloopSize chnget "LoopSize"

    ;kducktime ctrl7 1, 74, 0.001, 1
    kducktime chnget "Ducktime"
    kspeed = 1
    ktranspose = 1
    koffset = 0.5    

    kloopSize *= gkloopSizeMod
    kspeed = gkspeed
    printk2 kloopSize

    kloopSize port kloopSize, 0.1

    if kswitchBuffer == 0 then 
        giFreezeBuff = giFreezeBuff1
    else
        giFreezeBuff = giFreezeBuff2
    endif

    kplayToggle ctrl7 1, 55, 0, 1
    ktmp init 0
    if trigger(kplayToggle,0.5,0)==1 then
        ktmp = (ktmp+1)%2
    endif
    kplay = ktmp == 1 ? 1 : kstutter

    a1 BufferPlay giFreezeBuff, kplay, koffset, kloopSize, kducktime, kspeed, ktranspose
    a2 BufferPlay giFreezeBuff, kplay, koffset, kloopSize, kducktime, kspeed, ktranspose, 0.5
 

    outs a1,a2;a1+a5+a7,a1+a6+a7

endin


instr 2 

    ; Reverse toggle
    kreverse ctrl7 1, 21, 1, -1

    ; Speed control
    ;initc7 1, 71, 0.3
    ;kspeedCtrl ctrl7 1, 71, 0, 1
    kspeedCtrl chnget "Speed"

    ; Speed modifier
    ;initc7 1, 76, 0.1
    ;kspeedMod ctrl7 1, 76, 1, 11
    kspeedMod chnget "SpeedMod"
    kspeedMod = int(kspeedMod)

    ; Random tempo
    ;krandTempoOnOff ctrl7 1, 22, 0, 1
    krandTempoOnOff chnget "RandSize"
    ;krandTempoSpeed ctrl7 1, 18, 0.5, 10
    krandTempoSpeed chnget "RandSizeFreq"
    krandTempoSpeed *= krandTempoOnOff

    ; Random speed
    ;krandSpeedOnOff ctrl7 1, 23, 0, 1
    krandSpeedOnOff chnget "RandPitch"
    ;krandSpeedSpeed ctrl7 1, 19, 0.5, 10
    krandSpeedSpeed chnget "RandPitchFreq"
    krandSpeedSpeed *= krandSpeedOnOff

    ; Speed quantisation modes:
    ; 0: Free
    ; 1: Harmonic 
    ; 2: Fifths and Ocatves
    ; 3: Chromatic

    kSpeedQuantizeMode = 1

    if kSpeedQuantizeMode == 0 then 
        kspeed = (kspeedCtrl * 2)
        ;printks "Quantize mode %d\n", 0, kSpeedQuantizeMode
        printk2 kspeed
    elseif kSpeedQuantizeMode == 1 then 
        kharmonicScale[] fillarray 0.125, 0.25, 0.5, 0.75, 1, 1.25, 1.5, 1.75, 2, 2.25, 2.5, 2.75,3 
        kharmonicIdx = int(kspeedCtrl * 12.99)
        kspeed = kharmonicScale[kharmonicIdx]  
    elseif kSpeedQuantizeMode == 2 then 
        kfifthScale[] fillarray 0.25, 0.333333333333, 0.5, 0.6666666667, 1, 1.5, 2, 3, 4 
        kspeedIdx = int(kspeedCtrl * 8.99)
        kspeed = kfifthScale[kspeedIdx]  
    elseif kSpeedQuantizeMode == 3 then 
        kchromaScale[] fillarray 1, 1.05946309436, 1.12246204831, 1.18920711501, 1.2599210499, 1.33483985417, 1.41421356238, 1.49830707688, 1.58740105198, 1.68179283052, 1.78179743629, 1.88774862538, 2.0
        kchromaIdx = int(kspeedCtrl * 12.99)
        kspeed = kchromaScale[kchromaIdx]
    endif 

    kspeed *= kreverse
    kspeed *= kspeedMod

    ktempoDivisions[] fillarray 0.125, 0.1666666675, 0.25, 0.33333333333, 0.5, 0.6666666667, 0.75, 1
    kspeedModifiers[] fillarray 0.25, 0.333333333, 0.5, 0.6666666667, 0.75, 1, 1.25, 1.5, 1.75, 2, 2.25, 2.5, 2.75, 3
    ktempoMetro metro krandTempoSpeed
    ktempo_randIdx trandom ktempoMetro, 0, 6.99
    ktempo_randIdx limit ktempo_randIdx, 0, 6.99

    kspeedMetro metro krandSpeedSpeed
    kspeed_randIdx trandom kspeedMetro, 0, 12.99
    kspeed_randIdx limit kspeed_randIdx, 0, 12.99

    ksizeDivision = ktempoDivisions[ktempo_randIdx]
    ktempoDivision = kspeedModifiers[kspeed_randIdx] 

    ksizeDivision = krandTempoOnOff == 1 ? ksizeDivision : 1
    gkloopSizeMod = ksizeDivision
    ktempoDivision = krandSpeedOnOff == 1 ? ktempoDivision : 1 
    kspeed *= ktempoDivision

    gkspeed = kspeed
    printk2 kspeed

endin

instr 3 

    irb = ftlen(giRingBuff)
    ifb = ftlen(giFreezeBuff)
    prints "Length of RingBuffer: %d\n", irb
    prints "Length of FreezeBuffer: %d\n", ifb

    gkStutter = 1

endin


    instr 4 

    a1,a2 ins

    outs a1, a2

    endin

</CsInstruments>
<CsScore>
f 0 z
i1 0 86400
i2 0 86400
i4 0 86400

f 2 0 0 1 "pstereo_loop_mono.wav" 0 0 0

</CsScore>
</CsoundSynthesizer>


