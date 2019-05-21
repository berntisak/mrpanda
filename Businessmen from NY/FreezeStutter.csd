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
    giRecBuff               ftgen   0, 0, giBufferLen, 2, 0
    giFreezeBuff            ftgen   0, 0, (giBufferLen*2), 2, 0

    giTmpBuff               ftgen   0, 0, giBufferLen, 2, 0


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
        /*   
            ; Anti-click
            kidx = 0 
            istep = 1 / ksmps
            while kidx < ksmps then 
                ain[kidx] = ain[kidx] * (istep * kidx)
                kidx += 1
            od
        */
    endif

 ;   if krecording == 1 then 
        kidx = 0
        while (kidx < ksmps) do
            kval = ain[kidx]
            if krecIdx < ibuffLen-1 then 
                krecIdx += 1
                tablew kval, krecIdx, ibuffer, 0
                ;tablegpw giForwardsBuff
                ;krecIdx += 1
            else  
                printks "Done recording to buffer %d at idx %d\n", 10, ibuffer, krecIdx
            endif
            kidx += 1
        od
 ;   endif 

    xout krecIdx 

endop

opcode BufferPlay, a, ikkkkkk

    ibuffer, kplaying, koffset, kloopSize, kducktime, kspeed, ktranspose xin

    kspeed *= ktranspose
    kloopSize *= ktranspose
    ibuffLen = ftlen(ibuffer)
    /*
    ksizeDivision = ktempoDivisions[ktempo_randIdx]
    ktempoDivision = kspeedModifiers[kspeed_randIdx] 

    kwindowSize *= ksizeDivision
    kspeed *= ktempoDivision
    */

    kloopSizeScaled = (kloopSize*(ibuffLen-1)) 
    
    krate = 1 / (ibuffLen / sr) 

    ; OFFSET DOESNT REALLY MAKE SENSE NOW 
    ; I WANT TO SHIFT THE PHASE OF THE PHASOR INSTEAD

    andx phasor (a(krate) / a(kloopSize)) * a(kspeed), i(koffset)
    andxScaled = andx * a(kloopSizeScaled)

    klocal_off = (ibuffLen-1)-(kloopSizeScaled*0.5)

    if kplaying == 1 then 
        aout table3 (andxScaled-ksmps) + klocal_off, ibuffer, 0, ksmps, 1
        ;aout table3 andxScaled-a(koffset), ibuffer, 0, ksmps, 1
        ;aout lposcil3 1, kspeed, 0, kloopSizeScaled, ibuffer
    else 
        aout = 0
    endif

    aout ducking aout, andx, kducktime

    xout aout

endop 

gkStutter = 0

instr 100
	aL, aR ins
    ain = aL+aR

    kplay init 0
    kringIdx Ringbufferer ain, giRingBuff

    a0 BufferPlay giRingBuff, 1, ksmps, 1, 0, 1, 1

    outs a0, a0
endin

instr 1

	aL, aR ins
    ain = aL+aR

    kplay init 0

    kringIdx Ringbufferer ain, giRingBuff

    kstutter = gkStutter
    ; After hitting stutter, do the following:
    if trigger(kstutter, 0.5, 0) == 1 then 
        ; 1. copy Ringbuffer to FreezeBuff
        ; tablecopy giFreezeBuff, giRingBuff

        ; A manual tablecopy instead which copies from ringBuffIdx 
        ; to idx=0 in new table
        ; Could this be made into an opcode instead or optimized in a way?
        kcopyToIdx = giBufferLen-1
        kcopyFromIdx = kringIdx ; Should wrap around here
        kfromArr[] init giBufferLen
        ktoArr[] init giBufferLen

        printks "Start copying...at %d\n", 0, kringIdx

        copyf2array kfromArr, giRingBuff 
        while (kcopyToIdx >= 0) do
            ;printks "Copying %f from idx %d to idx %d\n", 0, kfromArr[kcopyFromIdx], kcopyFromIdx, kcopyToIdx
            ktoArr[kcopyToIdx] = kfromArr[kcopyFromIdx]
            kcopyToIdx -= 1
            kcopyFromIdx = kcopyFromIdx > 0 ? kcopyFromIdx-1 : giBufferLen-1
        od
        copya2ftab ktoArr, giFreezeBuff
        copya2ftab kfromArr, giTmpBuff

        ; 2. set recording to ON
        kstartRec = 1
    endif

    ; 3. start recording to FreezeBuff with offset 
    ; set to recIdx outputted from Ringbuffer 
    koffset = giBufferLen-1
    krecIdx BufferRec ain, kstartRec, koffset, giFreezeBuff  
    kdd BufferRec ain, kstartRec, 0, giRecBuff

    kplay = krecIdx < (giBufferLen*2)-1 ? 0 : 1
    printk2 kplay
    kstartRec = kplay == 1 ? 0 : kstartRec

    kloopSize init 0.15
    ;kloopSize oscil 0.1, 0.05
    ;kloopSize += 0.101
    kloopSize ctrl7 1, 77, 0.001, 1
    printk2 kloopSize

    kducktime = 1
    kspeed = 1
    ktranspose = 1
    koffset = 0.5 ;0 ;((giBufferLen-1)  - ksmps) - (kloopSize/2)    
;   ibuffer, kplaying, koffset, kloopSize, kducktime, kspeed, ktranspose xin
    a1 BufferPlay giFreezeBuff, kplay, koffset, kloopSize, kducktime, kspeed, ktranspose
   ; a2 BufferPlay giFreezeBuff, kplay, koffset-0.5, kloopSize, kducktime, kspeed, ktranspose
 
 /*
    a5 BufferPlay giFreezeBuff, kplay, koffset, kloopSize, kducktime, kspeed*2, ktranspose
    a6 BufferPlay giFreezeBuff, kplay, koffset, kloopSize, kducktime, kspeed, ktranspose*2
    a7 BufferPlay giFreezeBuff, kplay, koffset, kloopSize, kducktime, kspeed*0.5, ktranspose
 ;   a2 BufferPlay giRecBuff, kplay, 0, kloopSize, kducktime, kspeed, ktranspose
 ;   a3 BufferPlay giTmpBuff, kplay, 0, kloopSize, kducktime, kspeed, ktranspose
*/
    outs a1,a1;a1+a5+a7,a1+a6+a7

endin

instr 2 

    irb = ftlen(giRingBuff)
    ifb = ftlen(giFreezeBuff)
    prints "Length of RingBuffer: %d\n", irb
    prints "Length of FreezeBuffer: %d\n", ifb

    gkStutter = 1

endin

  instr 3; prints the values of table 1 or 2
          prints    "%nFunction Table %d:%n", p4
indx      init      0
loop:
ival      table     indx, p4
          prints    "Index %d = %f%n", indx, ival
          loop_lt   indx, 1, 64, loop
  endin

instr 4 

a1,a2 ins

outs a1*0.3, a2*0.3
endin

</CsInstruments>
<CsScore>
f 0 z
i4 0 86400 
i1 3 86400
;i2 3 1


;i2 5 86400

f 2 0 0 1 "pstereo_loop_mono.wav" 0 0 0

</CsScore>
</CsoundSynthesizer>


