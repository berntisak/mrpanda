<CsoundSynthesizer>
<CsOptions>
-odac -iadc -b128 -B512 -m0d -Ma
</CsOptions>
<CsInstruments>
sr      = 44100
ksmps  	= 16
0dbfs	= 1
nchnls 	= 2

    gS_loop = "pstereo_loop_mono.wav"
    giSR filesr gS_loop
    ;giBufferLen filelen gS_loop
    giForwardsBuff = 2; ftgen 1, 0, 0, 1, gS_loop, 0, 0, 0

    
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

    xout ainput*kenv
endop


instr 1

    kpot1 ctrl7 7, 16, 0.01, 0.3
    kpot1 init 1
    kpot1 = 0.5
;    printk2 kpot1
    kpot1 port kpot1, 0.01

    giBufferLen = ftlen(2)
    kspeed = 1
    awindowSize interp kpot1
    awindowSizeRaw = awindowSize*(ftlen(giForwardsBuff)-1)

    krate = 1 / (giBufferLen / sr) 
    andx phasor (a(krate) / awindowSize) * a(kspeed)

    kenv init 1
    kidx = 0
    kducktime = 0.1

    andxRaw = andx * awindowSizeRaw
    aoutL table3 andxRaw, giForwardsBuff, 0, 0, 1

    aoutL ducking aoutL, andx, kducktime


    aout loscil .8, 1, p4, 1

    outs aoutL, aoutL
endin


</CsInstruments>
<CsScore>
i1 0 86400 2

f 2 0 0 1 "pstereo_loop_mono.wav" 0 0 0

;i2 0 86400
</CsScore>
</CsoundSynthesizer>

