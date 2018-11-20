<CsoundSynthesizer>
<CsOptions>
-odac -iadc -b128 -B512 -m0d -Ma
</CsOptions>
<CsInstruments>
sr      = 44100
ksmps  	= 64
0dbfs	= 1
nchnls 	= 2

; live input feedback table for granular delay (aka live follow mode)
        giBufferLen           = 524288
        giRingBuff              ftgen   0, 0, giBufferLen+1, 2, 0                             ; create empty buffer for live follow mode
        giFreezeBuff            ftgen   0, 0, giBufferLen+1, 2, 0


opcode Onset, kk, akkkkk
    a1, kresponse, katk_thresh, kmin_thresh, kRelThresh, kRelTime xin
    ;*********************
    ; attack detector module,
    ; written by Oeyvind Brandtsegg 2005 (obrandts@online.no)
    ;*********************
    ; use a1 as audio input
    ; kTrig is the output, it's 1 at an attack and zero at all other times.
    ; An alternative control signal is also output, named kState.
    ; kState goes to 1 at the time of an attack, and stays at 1 while the audio amplitude is above threshold,
    ; kState goes to -1 after the amplitude has dropped below threshold, awaiting the next attack.
    ;*********************

    /*
        chnset  5,      "AmpResponse"           ; in milliseconds
        chnset  1,      "AtckThresh"            ; in dB (plus dB, relative to previous rms measurement)
        chnset  -60,    "MinThresh"             ; in dB (minus dB scale with 0dB as max level)
        chnset  -6,     "RelThresh"             ; in dB (minus dB scale with 0dB as max level)
        chnset  0.5,    "RelTime"               ; release time for live sampling
    */

    /*
    kresponse       chnget  "AmpResponse"   ; in milliseconds
    katk_thresh     chnget  "AtckThresh"    ; in dB (plus dB, relative to previous rms measurement)
    kmin_thresh     chnget  "MinThresh"     ; in dB (minus dB scale with 0dB as max level)
    kRelThresh      chnget  "RelThresh"     ; in dB (minus dB with reference to the attack level)
    kRelTime        chnget  "RelTime"       ; release time (time to continue sampling after the signal has fallen below the release thresh)
    */
    kresponse init 5

    kresponseTrig   changed kresponse
    if kresponseTrig == 1 then ;goto DONT_CHANGE_RESPONSE
        reinit CHANGE_RESPONSE
    endif
    ;DONT_CHANGE_RESPONSE:

    ; detect signal attack 
    CHANGE_RESPONSE:
    iresponse       = i(kresponse) 
    idelaytime      = iresponse * 0.001
    a1_dly          delay   a1, idelaytime

    irms_freq       = 20;1/idelaytime                               ; lp filter frequency for rms analysis, in cps
    krms            rms     a1, irms_freq
    krms_prev       rms     a1_dly, irms_freq
    krms_dB         = dbfsamp(krms)
    krms_prev_dB    = dbfsamp(krms_prev)
    rireturn

    ;printks        "input rms %f %f %f %f %f %n", 1, krms_dB, krms_prev_dB, kmin_thresh, katk_thresh, kRelThresh

    attackAnalyze:
    ktrig           init 0
    ktrig           = ((krms_dB > krms_prev_dB + katk_thresh) && \  ; if current rms plus threshold is larger than previous rms
                    (krms_dB > kmin_thresh) ? \                  ; and current rms is over minimum attack threshold
                        1 : 0)                                      ; set trig signal to current rms

    ; detect signal rms below a certain percentage of the attack strength
    kCurAtckRms     samphold krms_dB, ktrig
    ;printks        "release %f %f %n", 1, kCurAtckRms, kRelThresh
    ;printk2 kCurAtckRms
    ksignalUnder    = (krms_dB < (kCurAtckRms + kRelThresh) ? 1 : 0)
    ktrigUnder      trigger ksignalUnder, 0.5, 0

    ; when signal below threshold, wait for irelease seconds
    ; if signal goes above threshold during release, don't release

    ; time stamping allow for delayed release trigger
    ktime           timeinsts
    ktimeMarkOff    init 0
    ktimeMarkOff    = (ktrigUnder > 0 ? ktime : ktimeMarkOff)
    kDeltaOff       = (ktime - ktimeMarkOff) * ksignalUnder
    ktrigOff        = (kDeltaOff > kRelTime ? ksignalUnder : 0)

    ;*********************
    ; kState is 1 after attack and while signal is above threshold level
    ; kState goes to -1 when signal has dropped below threshold and has stayed low for kRelTime seconds
    kState          init 0
    kState          = (ktrig > 0 ? 1 : kState)
    kState          = (ktrigOff > 0 ? -1 : kState)

    ;*********************
    ; kTrig is 1 at the time of an attack in the audio input, and zero at all other times
    kTrig           trigger kState, 0.5, 0
    kTrigOff        trigger kState, 0.5, 1  ; trigger signal when kState goes to -1 (after release)

    xout kTrig, kState
endop

instr 1 
	aL, aR ins

    ismp_len = ftlen(1)

   ; aL, aR flooper2 1, 1, 0, (ismp_len/sr)*0.5,0, 1  

    kamp init 0
    kfader1 ctrl7 1, 77, 0, 1

    if kfader1 > 0.5 && kamp < 1 then
        kamp += 0.01
    elseif kfader1 < 0.5 && kamp > 0 then 
        kamp -= 0.01
    endif
    kamp limit kamp, 0, 1

    printk2 kamp

   ; aL *= kamp
   ; aR *= kamp

    kstartFollow init 0
    

    kstartFollow   tablewa giRingBuff, aL/0dbfs, 0                                ; write audio a1 to table 
    kstartFollow   = (kstartFollow > (giBufferLen-1) ? 0 : kstartFollow)       ; reset kstart when table is full
        tablegpw giRingBuff
    kstartFollow += 1

    aModRead oscil 0.02, 0.5 
    aModRead += 0.021

    krate = 1 / (giBufferLen / sr) 
 
    andx phasor krate
    aout tablei (andx-(andx * aModRead))*giBufferLen, giRingBuff, 0

    kfader2 ctrl7 1, 78, 0, 1
    kTrig trigger kfader2, 0.5, 2
;    printk2 kTrig

    kresponse = 2
    katk_thresh = 1
    kmin_thresh = -60
    krel_thresh = -3    
    krel_time = 0.1

    kOnset, kStatus Onset aL, kresponse, katk_thresh, kmin_thresh, krel_thresh, krel_time
    ;printk2 kOnset

    kstatus, kchan, kdata1, kdata2 midiin
    kmiditrig init 0
    kreverse init 1
    if kstatus == 144 && kchan == 10 then
        if kdata1 == 72 && kdata2 > 0 then 
            kmiditrig += 1
            kmiditrig = kmiditrig % 2
        endif
        if kdata1 == 73 && kdata2 > 0 then 
            kreverse *= -1
            printk2 kreverse
        endif 
    endif 

    if changed(kmiditrig) == 1 then 
        tablecopy giFreezeBuff, giRingBuff
        printks "STUTTER!\n", 0
        reinit RESTART
    endif

    kfader3 ctrl7 1, 79, 0.003, 0.3    
    kfader4 ctrl7 1, 80, 0, 1

    kspeed init 1
    kspeed = 1;kfader4

    #define SEMITONE #1.05946309436#


    kspeedTable[] fillarray 0.125, 0.25, 0.5, 0.75, 1, 1.25, 1.5, 1.75, 2, 2.25, 2.5, 2.75,3 
    kspeedIdx = int(kfader4 * 12.99)
    kspeed = kspeedTable[kspeedIdx]  
    kspeed *= kreverse
    printk2 kspeed


/*
    kChroma[] fillarray 1, 1.05946309436, 1.12246204831, 1.18920711501, 1.2599210499, 1.33483985417, 1.41421356238, 1.49830707688, 1.58740105198, 1.68179283052, 1.78179743629, 1.88774862538, 2.00000000002
    kChromaIdx = int(kfader4 * 12.99)
    kspeed = kChroma[kChromaIdx]
    kspeed *= kreverse
    printk2 kspeed
*/

    kspeed port kspeed, 0.1

    kFreezeSize init 0.03
    kFreezeSize = kfader3
    kFreezeSize port kFreezeSize, 0.1
    aFreezeSize interp kFreezeSize
    aFreezeSizeRaw = aFreezeSize*(giBufferLen-1)


RESTART:
    iOffset = i(kstartFollow)
    ;aFreezeIdx sc_phasor a(kTrig), (giBufferLen/aFreezeSize)/sr, 0, 1 
    aFreezeIdx phasor (a(krate)/aFreezeSize)*a(kspeed)
    aFreezeIdxFifth phasor (a(krate)/aFreezeSize)*a(kspeed)*1.5
    aFreezeIdxOct phasor (a(krate)/aFreezeSize)*a(kspeed)*2
 
    aFreezeIdx *= giBufferLen * aFreezeSize
    aFreezeIdxFifth *= giBufferLen * aFreezeSize
    aFreezeIdxOct *= giBufferLen * aFreezeSize

    ktrig metro kfader1
    kslice trandom ktrig, 0.5, 1
    ;kslice gausstrig kfader1, kfader1, krand, 1 

    aFreezeOut table3 (aFreezeIdx-aFreezeSizeRaw), giFreezeBuff, 0, i(kstartFollow), 1
;    aFreezeOut table3 (aFreezeIdx+(aFreezeSizeRaw-ksmps)), giFreezeBuff, 0, i(kstartFollow), 1

    aFreezeOutFifth table3 (aFreezeIdxFifth-aFreezeSizeRaw), giFreezeBuff, 0, i(kstartFollow), 1

    aFreezeOutOct table3 (aFreezeIdxOct-aFreezeSizeRaw), giFreezeBuff, 0, i(kstartFollow), 1

/*
    atrig = a(kTrig) ;mpulse(1, 1/krate)
	ax sc_phasor atrig, krate, 0, 1
	asine oscili 0.2, ax*500+500
*/

    kfader5 ctrl7 1, 81, 0, 1
    kfader6 ctrl7 1, 82, 0, 1

    kfader7 ctrl7 1, 83, 0, 1
    kfader8 ctrl7 1, 84, 0, 1

    ;aout ntrpol aFreezeOut, aFreezeOutFifth, kfader5
    ;outs aout, aout
    out aFreezeOut + (aFreezeOutFifth*kfader7) + (aFreezeOutOct*kfader8)
	;outs aL, aR

endin



</CsInstruments>
<CsScore>
i1 0 86400
f1 0 0 1 "spor1.wav" 0 0 0
</CsScore>
</CsoundSynthesizer>


