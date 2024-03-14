;----------------------------------------------------------------------------
; 
; Programa Principal (em C) 
; 
;----------------------------------------------------------------------------

//-----------------------------------------------------------------------------
// Includes
//-----------------------------------------------------------------------------

#include <c8051f020.h>                 // SFR declarations
#include <stdio.h>

//-----------------------------------------------------------------------------
// 16-bit SFR Definitions for 'F02x
//-----------------------------------------------------------------------------

sfr16 DP       = 0x82;                 // data pointer
sfr16 TMR3RL   = 0x92;                 // Timer3 reload value
sfr16 TMR3     = 0x94;                 // Timer3 counter
sfr16 ADC0     = 0xbe;                 // ADC0 data
sfr16 ADC0GT   = 0xc4;                 // ADC0 greater than window
sfr16 ADC0LT   = 0xc6;                 // ADC0 less than window
sfr16 RCAP2    = 0xca;                 // Timer2 capture/reload
sfr16 T2       = 0xcc;                 // Timer2
sfr16 RCAP4    = 0xe4;                 // Timer4 capture/reload
sfr16 T4       = 0xf4;                 // Timer4
sfr16 DAC0     = 0xd2;                 // DAC0 data
sfr16 DAC1     = 0xd5;                 // DAC1 data

//-----------------------------------------------------------------------------
// Global CONSTANTS
//-----------------------------------------------------------------------------

#define SYSCLK       22118400          // SYSCLK frequency in Hz
#define BAUDRATE     115200            // Baud rate of UART in bps

//-----------------------------------------------------------------------------
// Function PROTOTYPES
//-----------------------------------------------------------------------------

void SYSCLK_Init (void);
void PORT_Init (void);
void UART0_Init (void);

extern void INIT(void);

extern char SetGanho(char ganho);	// funcao que calcula o ganho e respectiva correccao

//-----------------------------------------------------------------------------
// Global VARIABLES
//-----------------------------------------------------------------------------
	  
unsigned int data frequencia;		 	// frequencia dada pelo utilizador
										// usada para calcular passo

extern unsigned int data passo;		// valor calculado a partir da frequencia
extern unsigned char data desfase;	// desfasagem pedida pelo utilizador

extern char data tipoonda;				// tipo de onda a gerar

//-----------------------------------------------------------------------------
// MAIN Routine
//-----------------------------------------------------------------------------

void main (void) {

   unsigned char amplitude;
   unsigned char desfasei;

   WDTCN = 0xde;                       // disable watchdog timer
   WDTCN = 0xad;

   SYSCLK_Init ();                     // initialize oscillator
   PORT_Init ();                       // initialize crossbar and GPIO
   UART0_Init ();                      // initialize UART0

   INIT ();			       // define timer3 e chama programa para fazer tabela em ASM

printf ("\n\n------------------------------\nGerador de ondas inicializado!\n\n");

   printf ("Tipo de onda: (1) seno (2) triangular (3) quadrada:\n");   	// pede onda a gerar
   scanf ("%2bu", &tipoonda);				   							//

   printf ("\nFrequencia (1 - 50000 Hz):\n");     			// pede frequencia
   scanf ("%u", &frequencia);								//

   printf ("\nAmplitude (1 - 100 %%):\n");    				// pede amplitude
   scanf ("%4bu", &amplitude);								//
   if (amplitude == 100 ) { amplitude = 0; };				// corrige valor, se=100
   
   printf ("\nDesfasagem (0 - 180 º):\n");    				// pede desfasagem
   scanf ("%4bu", &desfasei);								//

   passo = frequencia*128/100;	// calcula passo a partir da frequencia. 
								// 22118400 (CPU MHz) / 216 (timer counter) = 102400
								// 131072 (2^17 bits) / 102400 = 1.28

   amplitude = amplitude*255/100;					// calcula amplitude absoluta

   desfase = desfasei*255/180;						// calcula desfasagem absoluta

   SetGanho(amplitude);								// chama funcao de calculo de ganho

   EA = 1;			       // habilita interrupcoes apenas no final

   printf ("\n\nPressione reset para alterar valores.\n\n");

while (1);

}


//-----------------------------------------------------------------------------
// Initialization Subroutines
//-----------------------------------------------------------------------------

//-----------------------------------------------------------------------------
// SYSCLK_Init
//-----------------------------------------------------------------------------
//
// This routine initializes the system clock to use an 22.1184MHz crystal
// as its clock source.
//
void SYSCLK_Init (void)
{
   int i;                              // delay counter

   OSCXCN = 0x67;                      // start external oscillator with
                                       // 22.1184MHz crystal

   for (i=0; i < 256; i++) ;           // wait for oscillator to start

   while (!(OSCXCN & 0x80)) ;          // Wait for crystal osc. to settle

   OSCICN = 0x88;                      // select external oscillator as SYSCLK
                                       // source and enable missing clock
                                       // detector
}

//-----------------------------------------------------------------------------
// PORT_Init
//-----------------------------------------------------------------------------
//
// Configure the Crossbar and GPIO ports
//
void PORT_Init (void)
{
   XBR0    |= 0x04;                    // Enable UART0
   XBR2    |= 0x40;                    // Enable crossbar and weak pull-ups
   P0MDOUT |= 0x01;                    // enable TX0 as a push-pull output
   P1MDOUT |= 0x40;                    // enable LED as push-pull output
}

//-----------------------------------------------------------------------------
// UART0_Init
//-----------------------------------------------------------------------------
//
// Configure the UART0 using Timer1, for <baudrate> and 8-N-1.
//
void UART0_Init (void)			
{
   SCON0  = 0x50;                      // SCON0: mode 1, 8-bit UART, enable RX
   TMOD   = 0x20;                      // TMOD: timer 1, mode 2, 8-bit reload
   TH1    = -(SYSCLK/BAUDRATE/16);     // set Timer1 reload value for baudrate
   TR1    = 1;                         // start Timer1
   CKCON |= 0x10;                      // Timer1 uses SYSCLK as time base
   PCON  |= 0x80;                      // SMOD00 = 1 (disable baud rate 
                                       // divide-by-two)
   TI0    = 1;                         // Indicate TX0 ready
}

