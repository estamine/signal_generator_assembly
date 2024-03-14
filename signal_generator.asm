;-----------------------------------------------------------------------------
;
; Programa de Interrupção e Inicializações (em ASM)
;
;-----------------------------------------------------------------------------

$include (c8051f020.inc)               ; Include register definition file.

;-----------------------------------------------------------------------------
; EQUATES
;-----------------------------------------------------------------------------

faseL equ R2 		// parte BAIXA da fase
faseM equ R0 		// parte MEDIA da fase

regH equ R6 		// registo de trabalho na retencao ALTA
regL equ R4			// registo de trabalho na retencao BAIXA

dfaseL equ R3		// parte BAIXA da fase desfasada
dfaseM equ R1		// parte MEDIA da fase desfasada

ganhoR equ R5		// ganho introduzido pelo utilizador e recalculado em _SetGanho

ganho data 18h+5 	// 18h = posição dos registos na memória. +5 = posição de R5 

public passo, desfase, INIT, _SetGanho, tipoonda  	// variaveis publicas (partilhadas com o programa principal)

codigo segment code									// nome dado ao inicio do codigo
dados segment data									// nome dado ao inicio dos dados
dadosBA segment data bitaddressable 				// nome dado ao inicio dos dados enderecados ao bit

;-----------------------------------------------------------------------------
; VARIABLES
;-----------------------------------------------------------------------------

		    rseg dadosBA

faseH: 		DS 1 		 // parte ALTA da fase (1 bit + 1 bit)
dfaseH:		DS 1 		 // parte ALTA da fase desfasada (1 bit + 1 bit)

            rseg dados

passo:   	DS	2   	// quanto a onda varia entre ciclos sucessivos (2 bytes, 16 bits)

desfase:	DS	1		// desfasagem introduzida pelo utilizador (1 byte, 8 bits)
	
ganhoCORR:	DS	1		// correccao do ganho calculado em _SetGanho

tipoonda:	DS  1   	// variavel com o tipo de onda escolhido pelo utilizador

;-----------------------------------------------------------------------------
; STACK
;-----------------------------------------------------------------------------

            ISEG  AT 80h

Pilha:      DS    20h

;-----------------------------------------------------------------------------
; RESET and INTERRUPT VECTORS
;-----------------------------------------------------------------------------
            
          ; Reset Vector
          cseg AT 0

          cseg    AT 73h       ; Vector de interrupção de Timer 3 Overflow
          anl     TMR3CN,#7fh  ; Clear Timer 3 Overflow Flag.

		  ljmp    RSI_TIM3

          cseg  AT 100h

			rseg codigo

RSI_Tim3:           	// subrotina de busca da tabela (seno), calculo das outras funcoes (quadrada e triangular)

	PUSH PSW			// guardar PSW na stack
	PUSH ACC	   		// guardar ACC na stack

	MOV PSW,#18h		// usar o banco 3 (register bank)

						// FASE
 	MOV A,faseL			// actualiza a fase BAIXA
	ADD A,passo+1		// 
	MOV faseL,A		   	// 		 
						
	MOV A,faseM		   	// actualiza fase MEDIA
	ADDC A,passo		// 
	MOV faseM,A			// 
						
	MOV A,faseH			// actualiza fase ALTA
	ADDC A, #0		   	// 
	ANL A,#1		   	// mascarar	para permanecer com apenas 1 bit
	MOV faseH,A			// 

	MOV A,faseL  		// actualiza desfase BAIXA
	MOV dfaseL,A    	//

	MOV A,desfase
	CJNE A,#0,desfasenaonula // verifica se há desfase e salta para desfasenaonula

	MOV A,faseM   		// actualiza desfase nula MEDIA
	MOV dfaseM,A	  	// 
	MOV dfaseH,faseH    //

	JMP testaonda		// saltar para teste de onda	

desfasenaonula:

	MOV A,faseM		   	// actualiza desfase MEDIA
	ADD A,desfase		// 
	MOV dfaseM,A		// 
						
	MOV A,faseH			// actualiza desfase ALTA
	ADDC A, #0		   	//
	ANL A,#1		   	// 
	MOV dfaseH,A		// 

testaonda:
	
	MOV A,tipoonda		// guarda no ACC o tipo de onda, 1 - seno, 2 - triangular, 3 - quadrada

	JNB ACC.1,seno			// 0001	seno
	JNB ACC.0,triangular	// 0010	triangular
							// 0011 quadrada

quadrada:					// se não é alguma das anteriores, é quadrada

	JNB faseH.0,alto		// verifica se fase está na primeira ou na segunda metade

baixo:

	MOV regL,#00h		// zero da onda BAIXA
	MOV regH,#00h		// zero da onda ALTA

	JMP SAIDA			

alto:

	MOV regL,#0F0h	    // maximo da onda BAIXA
	MOV regH,#0FFh		// maximo da onda ALTA

	CJNE ganhoR,#0,fazerganho  // se ganho for zero, nao faz ganho

	JMP SAIDA			

triangular:	

	JNB faseH.0,sobe	// verifica se fase esta na primeira (subida) ou na segunda metade (descida)

desce:					// contagem de cima para baixo

	MOV A,faseL			// fase BAIXA subtraida do maximo
	CPL A				//
	MOV regL,A			//

	MOV A,faseM		    // fase MEDIA subtraida do maximo
	CPL A			    //
	MOV regH,A			//

	CJNE ganhoR,#0,fazerganho  // se ganho for zero, nao faz ganho

	JMP SAIDA			

sobe:				    // contagem de baixo para cima

	MOV A,faseL			// fase BAIXA directamente posta no registo de trabalho BAIXO
	MOV regL,A		    //

	MOV A,faseM			// fase MEDIA directamente posta no registo de trabalho MEDIO
	MOV regH,A			//

	CJNE ganhoR,#0,fazerganho  // se ganho for zero, não faz ganho

	JMP SAIDA

seno:
 
//	CLR faseH.1	   		// comentado porque CLR ja feito pelo ANL - escolheria pagina 0 dos HIGH

	MOV EMI0CN,faseH    // escolha da pagina da memoria

 	MOVX A,@faseM		// obtencao da parte ALTA do valor da tabela de seno
	MOV regH,A			// registo de trabalho ALTO tem agora a parte ALTA do valor do seno

	XRL EMI0CN,#2		// agora vamos buscar a parte BAIXA do valor do seno

	MOVX A,@faseM		// obtencao da parte BAIXA do valor da tabela de seno
	MOV regL,A			// registo de trabalho BAIXO tem agora a parte BAIXA do valor do seno

	CJNE ganhoR,#0,fazerganho  // se ganho for zero, não faz ganho

	JMP SAIDA	

fazerganho:

	MOV B,ganhoR		// mover ganho para B
	MUL AB			    // multiplicar ganho (B) por regL (A) - resultado fica em B A

	MOV regL,B			// passar B para regL
	MOV B,ganhoR		// repor ganho em B
	MOV A,regH			// por parte alta em A
	
	MUL AB				// multiplicar ganho (B) por regH (A) - resultado fica em B A
	
	ADD A,regL			// somar a regL a parte BAIXA da nova multiplicacao
	MOV regL,A
	
	MOV A,B			 	// mudar B (parte ALTA da multiplicacao) para A
	ADDC A,#0			// somar com Carry (afectada anteriormente) a parte ALTA
	MOV regH,A		    // mover para regH o valor de A já afectado pela Carry

	MOV A,regL			// mover regL para A
	ADD A,ganhoCORR		// adicionar correccao do ganho
	MOV regL,A			// por em regL o resultado final

	MOV A,regH			// mover regH para A
	ADDC A,#0		    // somar com Carry (afectada anteriormente) a parte ALTA
	MOV regH,A			// por em regH resultado final

SAIDA:

   	MOV DAC0L,regL		// colocar nos registos da DAC0 os valores correspondentes
	MOV DAC0H,regH		//

seno1:				 	// obtencao do valor do seno desfasado
 
	MOV EMI0CN,dfaseH 	// escolha da pagina da memoria

	MOVX A,@dfaseM	  	// obtencao da parte ALTA do valor da tabela de seno
	MOV regH,A			// registo de trabalho ALTO tem agora a parte ALTA do valor do seno	

	XRL EMI0CN,#2		// agora vamos buscar a parte BAIXA do valor do seno

	MOVX A,@dfaseM		// obtencao da parte BAIXA do valor da tabela de seno
	MOV regL,A			// registo de trabalho BAIXO tem agora a parte BAIXA do valor do seno

SAIDA1:

   	MOV DAC1L,regL		// colocar nos registos da DAC1 os valores correspondentes
	MOV DAC1H,regH		//

FIM:

	POP ACC			// repor valor do Acumulador
	POP PSW			// repor PSW

	reti			// fazer return da interrupcao

TabSin:				// tabela com o primeiro quarto dos valores do seno

	DW	0x0000, 0x0190, 0x0320, 0x04B0, 0x0640, 0x07E0, 0x0970, 0x0B00
	DW	0x0C90, 0x0E20, 0x0FB0, 0x1130, 0x12C0, 0x1450, 0x15E0, 0x1770
	DW	0x18F0, 0x1A80, 0x1C10, 0x1D90, 0x1F10, 0x20A0, 0x2220, 0x23A0
	DW	0x2520, 0x26A0, 0x2820, 0x29A0, 0x2B20, 0x2C90, 0x2E10, 0x2F80
	DW	0x30F0, 0x3270, 0x33E0, 0x3540, 0x36B0, 0x3820, 0x3980, 0x3AF0
	DW	0x3C50, 0x3DB0, 0x3F10, 0x4070, 0x41C0, 0x4320, 0x4470, 0x45C0
	DW	0x4710, 0x4860, 0x49B0, 0x4AF0, 0x4C30, 0x4D70, 0x4EB0, 0x4FF0
	DW	0x5130, 0x5260, 0x5390, 0x54C0, 0x55F0, 0x5710, 0x5830, 0x5960
	DW	0x5A70, 0x5B90, 0x5C60, 0x5DD0, 0x5EF0, 0x6010, 0x6130, 0x6250
	DW	0x62E0, 0x63E0, 0x64E0, 0x65D0, 0x66C0, 0x67B0, 0x68A0, 0x6980
	DW	0x6A60, 0x6B40, 0x6C10, 0x6CF0, 0x6DC0, 0x6E90, 0x6F50, 0x7010
	DW	0x70D0, 0x7190, 0x7240, 0x7300, 0x73A0, 0x7450, 0x74F0, 0x7590
	DW	0x7630, 0x76D0, 0x7760, 0x77F0, 0x7870, 0x7900, 0x7980, 0x79F0
	DW	0x7A70, 0x7AE0, 0x7B50, 0x7BB0, 0x7C20, 0x7C80, 0x7CD0, 0x7D30
	DW	0x7D80, 0x7DC0, 0x7E10, 0x7E50, 0x7E90, 0x7EC0, 0x7F00, 0x7F30
	DW	0x7F50, 0x7F70, 0x7F90, 0x7FB0, 0x7FD0, 0x7FE0, 0x7FE0, 0x7FF0
	DW	0x7FF0

_SetGanho:			// funcao que calcula o ganho e respectiva correccao 

	MOV A,R7		// R7 registo de comunicacao (R7 parametro da funcao do PortaSerie)
	ANL A,#0F7h     // ganho passa a 7 bits	para facilidade de calculo

	MOV ganho,A		// passar para variavel ganho (R5 = 18 + 5) banco3

	MOV R7,A		// devolver valor do ganho para PortaSerie

	CLR A			// apagar A	
	CLR C		   	// apagar Carry

	SUBB A,ganho	// calculo intermedio (1 - G)
	
	RR A			// multiplicar por 8000 (valor medio da DAC)

	MOV ganhoCORR,A	// correccao de ganho a ser somado a ValorTabela*ganho

	ret

init_tabela: 		// construcao da tabela do seno a partir do quarto de seno de TabSin

	MOV DPTR, #TabSin	// por em DPTR local de inicio da TabSin
	MOV R7,#0			// posição zero da tabela leitura
	MOV R0,#0			// posição zero tabela escrita

quarto1:				// valores ALTOS seguidos de BAIXOS

	MOV A,R7		   	// posicao tabela de leitura em A (ALTO)
	INC R7			   	// incrementar posicao tabela leitura (incrementa de ALTO para BAIXO)

	MOVC A,@A+DPTR	   	// copiar para A os dados (ALTOS) da tabela

	ADD A,#80h			// adicionar 8000h ao valor, ou seja 80h a parte ALTA

	MOV EMI0CN,#0	    // escolher pagina 0 da memoria externa

	MOVX @R0,A		   	// mover para memoria externa no endereço dado por R0 os dados de A (ALTOS)

	MOV A,R7		 	// posicao tabela de leitura em A (BAIXO)
	INC R7			  	// incrementa posicao tabela leitura (de BAIXO de anterior para ALTO de posterior)

	MOVC A,@A+DPTR	  	// copiar para A os dados (BAIXOS) da tabela

	MOV EMI0CN,#2 	   	// escolher pagina 2 da memoria externa

	MOVX @R0,A		   	// mover para memoria externa no endereço dado por R0 os dados de A (BAIXOS)
	INC R0				// incrementar posicao na tabela de escrita

	MOV A,R7			// copiar R7 para A para testar seguidamente se R7 deu a volta (128 ALTOS + 128 BAIXOS)

	JNZ quarto1		   	// se R7 ainda nao deu a volta, repetir operacoes para a posicao seguinte

	INC DPTR			// porque a tabela TabSin tem 129 valores
	INC DPTR			//

quarto2:				// valores BAIXOS seguidos de ALTOS

// EMI0CN = #2    | 
// R7 = #0		  | valores actuais das variaveis
// R0 = #128	  |
		   
	DEC R7				// decrementar posicao tabela leitura
	MOV A,R7		   	// posicao tabela de leitura em A (BAIXO)

	MOVC A,@A+DPTR	   	// copiar para A os dados (BAIXOS) da tabela

	// escolher a página 2 *aqui* com XRL do EMI0CN	--- já está

	MOVX @R0,A		   	// mover para memoria externa no endereço dado por R0 os dados de A (BAIXOS)
 
	DEC R7			  	// decrementar posicao tabela (de ALTO de posterior para BAIXO de anterior)
	MOV A,R7		 	// por em A posicao da tabela (ALTO)

	MOVC A,@A+DPTR	  	// copiar para A dados (ALTOS) da tabela

	ADD A,#80h			// adicionar 8000h ao valor, ou seja 80h a parte high

	MOV EMI0CN,#0 	   	// escolher pagina 0 da memoria externa

	MOVX @R0,A		   	// mover para memoria externa no endereço dado por R0 os dados de A (ALTOS)
	INC R0				// incrementar posicao na tabela de escrita

	MOV EMI0CN,#2 	   	// escolher pagina 2 da memoria externa

	MOV A,R7			// copiar R7 para A para testar seguidamente se R7 deu a volta (128 ALTOS + 128 BAIXOS)
	JNZ quarto2		   	// se R7 ainda nao deu a volta, repetir as operacoes para a posicao seguinte

	MOV DPTR, #TabSin	// por em DPTR local de inicio da TabSin

quarto3:			    // valores ALTOS seguidos de BAIXOS

// EMI0CN = #2	  |
// R7 = #0		  | valores actuais das variaveis
// R0 = #0		  |

	MOV A,R7		   	// posicao tabela de leitura em A (ALTO)
	INC R7			   	// incrementar posicao tabela leitura (incrementa de ALTO para BAIXO)

	MOVC A,@A+DPTR	   	// copiar para A os dados (ALTOS) da tabela

	MOV R5,A			// guardar valor ALTO

	MOV A,R7		   	// posicao tabela de leitura em A (BAIXO)
	INC R7			   	// incrementar posicao tabela leitura (de BAIXO de anterior para ALTO de posterior)

	MOVC A,@A+DPTR	   	// copiar para A os dados (BAIXOS) da tabela

	MOV R6,A			// guardar valor BAIXO

	CLR A				// apagar acumulador
	CLR C				// apagar carry

	SUBB A,R6			// subtrair valor BAIXO do maximo

	MOV EMI0CN,#3 	   	// escolher pagina 3 da memoria externa
	
	MOVX @R0,A			// mover para memoria externa no endereço dado por R0 os dados de A (BAIXOS)

	MOV A,#80h			// mover para A valor medio da DAC
	SUBB A,R5			// subtrair valor ALTO

	MOV EMI0CN,#1 	   	// escolher pagina 1 da memoria externa
	MOVX @R0,A			// mover para memoria externa no endereço dado por R0 os dados de A (ALTOS)

	INC R0				// incrementar posicao da tabela de escrita

	MOV A,R7			// copiar R7 para A para testar seguidamente se R7 deu a volta (128 ALTOS + 128 BAIXOS)
	JNZ quarto3		   	// se R7 ainda nao deu a volta, repetir as operacoes para a posicao seguinte

	INC DPTR			// porque a tabela TabSin tem 129 valores
	INC DPTR			//

quarto4:				// valores BAIXOS seguidos de ALTOS

// EMI0CN = #3	  |
// R7 = #0		  | valores actuais das variaveis
// R0 = #128	  |
   
	DEC R7				// decrementar posicao tabela leitura
	MOV A,R7		   	// posicao tabela de leitura em A (BAIXO)

	MOVC A,@A+DPTR	   	// copiar para A os dados (BAIXOS) da tabela

	MOV R6,A			// guardar valor BAIXO

	DEC R7				// decrementar posicao tabela leitura
	MOV A,R7		   	// posicao tabela de leitura em A (ALTO)

	MOVC A,@A+DPTR	   	// copiar para A os dados (ALTO) da tabela

	MOV R5,A			// guardar valor ALTO

	CLR A				// apagar acumulador
	CLR C				// apagar carry

	SUBB A,R6			// subtrair valor BAIXO do maximo

	MOV EMI0CN,#3 	   	// escolher pagina 3 da memoria externa

	MOVX @R0,A			// mover para memoria externa no endereço dado por R0 os dados de A (BAIXOS)

	MOV A,#80h			// mover para A valor medio da DAC
	SUBB A,R5			// subtrair valor ALTO

	MOV EMI0CN,#1 	   	// escolher pagina 1 da memoria externa
	MOVX @R0,A			// mover para memoria externa no endereço dado por R0 os dados de A (ALTOS)

	INC R0				// incrementar posicao da tabela de escrita

	MOV A,R7			// copiar R7 para A para testar seguidamente se R7 deu a volta (128 ALTOS + 128 BAIXOS)
	JNZ quarto4		   	// se R7 ainda nao deu a volta, repetir as operacoes para a posicao seguinte

	ret

INIT:

    MOV TMR3RLL,#low(-216)  // Parte baixa do registo contador Timer3 
    MOV TMR3RLH,#high(-216) // Parte alta do registo Timer3

	MOV TMR3CN,#6     		// Timer3 não usa o relógio do sistema dividido por 12

	MOV DAC0CN,#8Ch			// Habilita DAC0, justifica 12 bits em 16 à esquerda
							// actualiza quando timer3 overflow 
	MOV DAC1CN,#8Ch			// Habilita DAC1, justifica 12 bits em 16 à esquerda
							// actualiza quando timer3 overflow 

    ORL EIE2, #1			// Habilita Interrupção Timer 3

	CALL init_tabela		// Inicializa a construção da tabela

    ret

END
