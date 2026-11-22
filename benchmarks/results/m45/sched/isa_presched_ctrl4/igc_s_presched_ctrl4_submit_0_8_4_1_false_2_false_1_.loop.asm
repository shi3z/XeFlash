        send.ugm (1|M0)          r45      r38  null:0  0x0            0x0240F580           {I@4,$18} // wr:1+0, rd:4; load.ugm.d32x64t.a64
        send.ugm (1|M0)          r49      r37  null:0  0x0            0x0240F580           {I@3,$23} // wr:1+0, rd:4; load.ugm.d32x64t.a64
        send.ugm (1|M0)          r53      r37  null:0  0x100000            0x0240F580           {$24} // wr:1+0, rd:4; load.ugm.d32x64t.a64.flat[A+0x100]
        send.ugm (1|M0)          r57      r37  null:0  0x200000            0x0240F580           {$25} // wr:1+0, rd:4; load.ugm.d32x64t.a64.flat[A+0x200]
        send.ugm (1|M0)          r65      r37  null:0  0x300000            0x0240F580           {$26} // wr:1+0, rd:4; load.ugm.d32x64t.a64.flat[A+0x300]
        add (1|M0)               r18.1<1>:d    r18.1<0;1,0>:d    2:w               {I@1}
        sync.allwr                           ($7,$13,$14,$15,$16,$17,$19,$20,$21,$22)
        dpas.8x8 (16|M0)         r136:d        r136:d            r81:s4            r61.0:b          {Atomic,$12.dst}
        dpas.8x8 (16|M0)         r120:d        r120:d            r81:s4            r69.0:b          {Atomic}
        dpas.8x8 (16|M0)         r104:d        r104:d            r81:s4            r73.0:b          {Atomic}
        dpas.8x8 (16|M0)         r88:d         r88:d             r81:s4            r77.0:b          {$12}
        add (1|M0)               r18.4<1>:uq   r38.0<0;1,0>:uq   0x100:uw
        add (1|M0)               r39.0<1>:q    r37.0<0;1,0>:q    r18.2<0;1,0>:q
        cmp (1|M0)    (lt)f3.1   null<1>:ud    r18.1<0;1,0>:ud   r4.10<0;1,0>:ud  {I@3}
(W&f3.1) jmpi                                L2288
        mov (1|M0)               r37.0<1>:uq   r39.0<0;1,0>:uq                  {Compacted,@3,$26.src}
        mov (1|M0)               r38.0<1>:uq   r18.4<0;1,0>:uq                  {Compacted,$18.src}
(W)     jmpi                                 L2416
        sync.nop                             null                             {$12.src}
        send.ugm (1|M0)          r81      r38  null:0  0x100000            0x0240F580           {I@2,$19} // wr:1+0, rd:4; load.ugm.d32x64t.a64.flat[A+0x100]
        send.ugm (1|M0)          r61      r39  null:0  0x0            0x0240F580           {$20} // wr:1+0, rd:4; load.ugm.d32x64t.a64
        send.ugm (1|M0)          r69      r39  null:0  0x100000            0x0240F580           {$17} // wr:1+0, rd:4; load.ugm.d32x64t.a64.flat[A+0x100]
        send.ugm (1|M0)          r73      r39  null:0  0x200000            0x0240F580           {$21} // wr:1+0, rd:4; load.ugm.d32x64t.a64.flat[A+0x200]
        send.ugm (1|M0)          r77      r39  null:0  0x300000            0x0240F580           {$22} // wr:1+0, rd:4; load.ugm.d32x64t.a64.flat[A+0x300]
        add (1|M0)               r37.0<1>:q    r37.0<0;1,0>:q    r18.3<0;1,0>:q   {$26.src}
        add (1|M0)               r38.0<1>:uq   r38.0<0;1,0>:uq   0x200:uw              {$19.src}
        sync.allwr                           ($12,$23,$24,$25,$26)
        dpas.8x8 (16|M0)         r136:d        r136:d            r45:s4            r49.0:b          {Atomic,$18.dst}
        dpas.8x8 (16|M0)         r120:d        r120:d            r45:s4            r53.0:b          {Atomic}
        dpas.8x8 (16|M0)         r104:d        r104:d            r45:s4            r57.0:b          {Atomic}
        dpas.8x8 (16|M0)         r88:d         r88:d             r45:s4            r65.0:b          {$18}
(W&f3.1) jmpi                                L2016
