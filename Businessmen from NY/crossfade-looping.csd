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


instr 1
    giBufferLen = ftlen(2)
    kspeed = 1
    kwindowSize = 1

    krate = 1 / (giBufferLen / sr) 
    andx phasor (a(krate) / a(kwindowSize)) * a(kspeed)

    aoutL table3 andx, giForwardsBuff, 0, ksmps, 1

    aout loscil .8, 1, p4, 1

    outs aoutL, aout
endin


</CsInstruments>
<CsScore>
i1 0 86400 2

f 2 0 0 1 "pstereo_loop_mono.wav" 0 0 0

;i2 0 86400
</CsScore>
</CsoundSynthesizer>

