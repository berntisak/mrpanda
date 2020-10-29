inlets = 1;
outlets = 1;

var x = 0;
var pres_x = 0;
var y = 0;
var i = 0;
var p = new Patcher();
p = this.patcher;

var sprintf = patcher.newdefault(10, 280, "sprintf", "%s","%ld");
var send = patcher.newdefault(10, 310, "send", "---displayVal");
var osc = patcher.newdefault(130, 310, "udpsend", "127.0.0.1", "9999");
p.connect(sprintf,0,send,0);
p.connect(sprintf,0,osc,0);
p.connect("ip1",0, osc,0);

var Knobs = new Array(64);
var Triggs = new Array(64);
var Texts = new Array(64);
var Routes = new Array(64);
var Messes = new Array(64);


function bang() {
	//p.fullscreen(i%2);
	var knob = patcher.newdefault(10+x,10,"live.dial");
	var trigg = patcher.newdefault(10+x,70, "t", "b","i");
	var text = patcher.newdefault(10+x,100,"textedit");	
	var route = patcher.newdefault(10+x, 130, "route", "text");
	//var m = patcher.newdefault(10+i,130, "message", "set", "_parameter_shortname");
	var mess = this.patcher.newobject("message", 10+x, 160,100,10, "_parameter_shortname", "$1");
	knob.presentation(1);
	text.presentation(1);
	knob.patching_rect(10+x, 10, 50, 50);
	text.patching_rect(10+x, 100, 100, 25);
	knob.presentation_rect(35+pres_x, 30+y, 50, 50);
	text.presentation_rect(10+pres_x, 80+y, 100, 25);
	text.lines(1);
	text.keymode(true);
	
	Knobs[i] = knob;
	Triggs[i] = trigg;
	Texts[i] = text;
	Routes[i] = route;
	Messes[i] = mess;
	i += 1;
	
	
	p.connect(knob,0,trigg,0);
	p.connect(trigg,0,text,0);
	p.connect(text,0,route,0);
	p.connect(route,0,mess,0);
	p.connect(mess,0,knob,0);
	p.connect(route,0,sprintf,0);
	p.connect(trigg,1,sprintf,1);
	x += 110;
	pres_x = x % 440;
	if (pres_x == 0) {
		y += 100;
	}
}

function reset() {
	x = 0;
	pres_x = 0;
	y = 0;
	for (var j = 0; j < 64; j++) {
		this.patcher.remove(Knobs[j]);
		this.patcher.remove(Triggs[j]);
		this.patcher.remove(Texts[j]);
		this.patcher.remove(Routes[j]);	
		this.patcher.remove(Messes[j]);				
	}
	i = 0;
}

function undo() {
	this.patcher.remove(Knobs[i-1]);
	this.patcher.remove(Triggs[i-1]);
	this.patcher.remove(Texts[i-1]);
	this.patcher.remove(Routes[i-1]);	
	this.patcher.remove(Messes[i-1]);	
	i -= 1;
	x -= 110;	
	pres_x = x % 440;
	if (pres_x == 0) {
		y -= 100;
	}
}
