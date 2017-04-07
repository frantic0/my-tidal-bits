
"My name is frantic o".speak
"and This is Electro-Buto".speak


s.postln;
s.addr;
s.serverRunning;
s.avgCPU;

s.boot;
s.options.numBuffers = 1024 * 256;
s.freeAll;
SuperDirt.start;
s.kill;

{Pan2.ar(SinOsc.ar(440,0,0.1),0.0)}.play
{SinOsc.ar(440*SinOsc.ar(4, mul:0.125, add:1), 0, 1)}.scope
{RLPF.ar(Saw.ar(333), SinOsc.ar(1).range(400, 14000), 0.1)}.freqscope

UGen.browse

"open /Users/francisco/Library/Application Support/SuperCollider/downloaded-quarks/Dirt-Samples".

SynthDescLib.global.read;
SynthDescLib.global[\tone].makeWindow;


######################################################

// Setup:
// 1. Eval this snippet for server boot and async load of SuperDirt
// 2. Execute the OSCdev func
// 3. Setup Max

(
// From https://github.com/musikinformatik/SuperDirt
// configure the sound server: here you could add hardware specific options
// see http://doc.sccode.org/Classes/ServerOptions.html
s.options.numBuffers = 1024 * 16; // increase this if you need to load more samples
s.options.memSize = 8192 * 16; // increase this if you get "alloc failed" messages
s.options.maxNodes = 1024 * 32; // increase this if you are getting drop outs and the message "too many nodes"

s.options.numOutputBusChannels = 2; // set this to your hardware output channel size, if necessary
s.options.numInputBusChannels = 2; // set this to your hardware input channel size, if necessary
// boot the server and start SuperDirt
s.waitForBoot {
	~dirt = SuperDirt(2, s); // two output channels, increase if you want to pan across more channels
	~dirt.loadSoundFiles;   // load samples (path containing a wildcard can be passed in)
	// for example: ~dirt.loadSoundFiles("/Users/myUserName/Dirt/samples/*");
	~dirt.loadSoundFiles("/Users/francisco/Music/Samples/*");
	s.sync; // wait for samples to be read
	~dirt.start(57120, [0, 0]);   // start listening on port 57120, create two orbits, each sending audio to channel 0. You can direct sounds to the orbits from tidal e.g. by: `# orbit "0 1 1"
}
)


######################################################

NetAddr.langPort

(
SynthDef(\stereosine, {
	arg freq=333, amp=0.4, pan=0.0; // we add a new argument
	var signal;
	signal = SinOsc.ar(freq, 0, amp);
	signal = Pan2.ar(signal, pan);
	Out.ar(0, signal);
	}).add // we add the synthdef to the server
)

a = Synth(\stereosine, [\freq, 777]); // we assign the synth to a variable
a.set(\freq, 444) // set the frequency from outside
a.set(\amp, 0.8)
a.set(\pan, -1)
a.set(\pan, 1)
a.set(\pan, 0)
a.free; // free the synth


// Check OSCdef, SynthDef, params, EnvGen, Blip, LFNoise1

(
SynthDef.new(\tone, {
	arg freq=40, nharm=12, detune=0.2, gate=0, pan=0, amp=1, out=0;
	var sig, env;
	// ADSR envelope controls the amplitude of the sound, gate closed by default
	env = EnvGen.kr(Env.adsr(0.05, 0.1, 0.5, 3), gate);
	// Source of the sound comes from Blip that generates harmonic partials
	// Fundamental frequency set with a detuning feature by multiplying it by a slow moving LFNoise ranging between negative and positive detuned values
	//
	sig = Blip.ar(
		freq *
		LFNoise1.kr(0.2!16).bipolar(detune.neg, detune).midiratio,
		nharm
	);
	sig = sig * LFNoise1.kr(0.5!16).exprange(0.1,1);
	sig = Splay.ar(sig);
	sig = Balance2.ar(sig[0], sig[1], pan);
	sig = sig * env * amp;
	Out.ar(out, sig);
}).add
)

x = Synth.new(\tone, [\gate, 1]);
x.set(\freq, 70)
x.set(\pan, 0)
x.set(\nharm, 120)
x.set(\detune, 2)
x.set(\amp, 1.9)
x.set(\gate, 0)



(
OSCdef.new(
	\toggle,
	{
		arg msg, time, addr, port;
		/*[msg, time, addr, port].postln;*/
		/*msg[1].postln;*/
		x.set(\freq, msg[1] * 100)
		/*x.set(\pan, msg[1].linexp(0, 1, 0.001, 1))*/
		/*x.set(\freq, msg[1].linexp(0,1,20,100))*/
	},
	'/pd'
);
)

OSCdef(\toggle).disable;

OSCdef.freeAll;


s.plotTree;


(
// Lowfreq sawtooth wave (seq of pops at sub audio freq) sent through a band pass filter (emphasize narrow range, attenuate the rest)
SynthDef.new(\foldsaw, {
	arg freq, detune=1, atk=0.01, dec=0.3, rel=3, c1=1, c2=(-1), gate=1, mincf=40, maxcf=12000, minrq=0.002, maxrq=0.2, boost=1.25, amp=1, out=0;
	var sig, env;
	env = EnvGen.kr(Env.adsr(atk, dec, 0.5, rel), gate, doneAction:2);
	sig = Saw.ar(
				freq +
				LFNoise1.kr(LFNoise1.kr(0.5!8).range(0.1,1).bipolar(detune))
	);
	5.do{	sig = (sig * boost).fold(-1.0, 1.0)	};
	sig = BPF.ar(
		sig,
		LFNoise1.kr({ExpRand(0.005, 0.05)}!8).exprange(mincf,maxcf),
		LFNoise1.kr({ExpRand(0.1,0.75)}!8).range(minrq, maxrq)
	);
	sig = Splay.ar(sig) * env * amp * 2;
	Out.ar(out, sig);
}).add;
)

y = Synth.new(\foldsaw);

y.set(\gate, 0);
y.set(\detune, 23);
y.set(\atk, 0);
y.set(\dec, 0);
y.set(\rel, 0);
y.set(\c1, 0);
y.set(\c2, 0);
y.set(\mincf, 0);
y.set(\maxcf, 0);
y.set(\minrq, 0.2);
y.set(\maxrq, 1);
y.set(\gate, 0) ;
y.set(\gate, 0);

(
// Create a group to make it easy to address all the synths as a group to set params
g = Group.new;
a = [];
/* MYO data << a_x << a_y << a_z << g_x << g_y << g_z  << x << y << z << w*/
// Motion data used to set message that controls 3 params
OSCdef.new(\myo, {
	arg msg, time, addr, port;
	/*[msg, time, addr, port].postln;*/
	/*msg[1..18].postln;*/
	/*[msg[1],msg[7],msg[8]].postln;*/
	g.set(
		// pitch controls detune, 1000Hz to 80Hz, affecting the rate of filtered pops; pointing up high detune will fuse the oscillation of the of the sawtooth
		\detune, msg[8].linexp(-1.00, 3.00, 0.001, 80),
		// roll controls filter quality left to right (hq to lq)
		\maxrq, msg[7].linexp(-1.0, 1.0, 0.01, 0.5),
		// acceleration makes folding distortion more pronounced
		\boost, (msg[1] * 10).linlin(-1.0, 1.0, 1, 16)
	);
	}, '/myo'
);

OSCdef(\myo).disable;

OSCdef.freeAll;
// Create 3 OSC defs for motion data, A & B buttons

OSCdef.new(\abutton, {
	arg msg, time, addr, port;
	/*[msg, time, addr, port].postln;*/
	[msg[1],msg[2]].postln;
	if(
		msg[1]==1,
		{
			a = a.add(
				Synth.new(
					\foldsaw,
					[
						\freq, exprand(1,8),
						\atk, exprand(2,8),
						\rel, exprand(2,8)
					],
					g
				)
			)
		}
	);
	}, '/a'
);

OSCdef(\abutton).disable;

OSCdef.new(\bbutton, {
	arg msg;
	[msg[1],msg[2]].postln;
	if(
		(msg[1]==1) && (a.size>0),
		{
			a[0].set(\gate, 0);
			a.removeAt(0);
		}
	);
	}, '/b'
);

OSCdef(\bbutton).disable;


######################################################

(
{
var singrain1, singrain2, sfgrain;
singrain1=SinOsc.ar(440,0,XLine.kr(1.0, 0.0001, 0.05));
singrain2=FSinOsc.ar(800, 0.0, Line.kr(1.0,0,0.05).squared);

[singrain1,singrain2]
}.plot(0.1,s)
)



//simple sine grain synthdef - note the all important doneAction
(
SynthDef(\sinegrain, {arg pan, freq, amp; var grain;

grain= SinOsc.ar(freq, 0, amp)*(XLine.kr(1.001,0.001,0.1,doneAction:2)-0.001);

Out.ar(0,Pan2.ar(grain, pan))}).add;
)

/****************************************************************/

//listen to a single grain;
Synth(\sinegrain,[\freq,rrand(100,10000),\amp, exprand(0.05,0.1), \pan, 1.0.rand2]);

//schedule 100 random grains over 1 second
(
{
100.do{arg i;

	Synth(\sinegrain,[\freq,rrand(100,10000),\amp, exprand(0.05,0.1), \pan, 1.0.rand2]);
	0.01.wait
};
}.fork
)


//schedule 200 random grains over time, decreasing the range of allowed random frequencies and lowering the density over time
(
{
2000.do{arg i;
var timeprop = (i/199.0)**3;

	Synth(\sinegrain,[\freq,exprand(100,3000-(20*i)),\amp, exprand(0.05,0.1), \pan, 1.0.rand2]);
	rrand((timeprop*0.1).max(0.01),timeprop*0.3).wait
};
}.fork
)

/****************************************************************/

Platform.resourceDir


b = Buffer.read(s,Platform.resourceDir +/+ "sounds/a11wlk01.wav");
b.play;

(
SynthDef(\sfgrain, {arg bufnum=0, pan=0.0, startPos=0.0, amp=0.1, dur=0.04;
var grain;

grain= PlayBuf.ar(1,bufnum, BufRateScale.kr(bufnum), 1, BufFrames.ir(bufnum)*startPos, 0)*(EnvGen.kr(Env.perc(0.01,dur),doneAction:2)-0.001);

Out.ar(0,Pan2.ar(grain, pan))}).add;
)


//individual grain
Synth(\sfgrain,[\bufnum, b.bufnum, \startPos,rrand(0.0,1.0),\amp, exprand(0.005,0.1), \pan, 1.0.rand2]);


//schedule 200 random soundfile playback grains over time, with random offset positions into the soundfile and lowering the density over time
(
{
200.do{arg i;
var timeprop = (i/199.0)**3;

	Synth(\sfgrain,[\bufnum, b.bufnum, \startPos,rrand(0.0,timeprop),\amp, exprand(0.005,0.1), \pan, 1.0.rand2]);
	rrand((timeprop*0.1).max(0.01),timeprop*0.4).wait
};
}.fork
)

(
var w, slid, lastval;
lastval=0.0;

w=Window("My Window", Rect(100,500,200,200));
//A 200 by 200 window appears at screen co-ordinates (100, 500)

slid=Slider(w,Rect(10,10,150,40)); //a basic slider object

slid.action_({lastval= slid.value;}); //this is the callback- the function is called whenever you move the slider

{
inf.do{arg i;

var prop, timestart, timeend;

prop= (i%300)/300;

timestart= prop*0.8;
timeend= prop*(0.8+(0.1*lastval));

	Synth(\sfgrain,[\bufnum, b.bufnum, \startPos,rrand(timestart,timeend),\amp, exprand(0.005,0.1), \pan, lastval.rand2, \dur, 0.1+(lastval*0.5)]);
	//max in this to avoid ever going near 0.0 wait time, which would crash the computer!
	(((lastval*0.2)+0.01).max(0.01)).wait
};
}.fork;


w.front;
)
