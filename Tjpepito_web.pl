/* =====================================================================
   File    : Tjpepito_web.pl
   Title   : Tower of Hanoi WEBSITE written in Prolog (SWI-Prolog)
   Author  : Pepito Tito Agoring

   DESCRIPTION
   -----------
   A complete website served by SWI-Prolog's built-in HTTP server.

     * Prolog  : runs the web server, solves Tower of Hanoi recursively,
                 and CHECKS every move against the rules.
     * Browser : shows the three towers (A, B, C), animates the moves and
                 lets you play by hand (rules are enforced there too).

   PAGES / ROUTES
   --------------
     /                -> the game page (HTML, CSS, JavaScript)
     /solve?disks=N   -> JSON list of all moves computed by Prolog

   RULES OF THE PUZZLE
   -------------------
     1. Move only ONE disk at a time.
     2. Only the TOP disk of a tower can be moved.
     3. Never place a larger disk on top of a smaller disk.

   HOW TO RUN
   ----------
     $ swipl Tjpepito_web.pl
     ?- start.            % starts the server and opens http://localhost:8080
     ?- stop.             % stops the server
   ===================================================================== */

:- use_module(library(http/thread_httpd)).
:- use_module(library(http/http_dispatch)).
:- use_module(library(http/http_parameters)).
:- use_module(library(www_browser)).

:- initialization(show_help).

/* ---------------------------------------------------------------------
   SECTION 1: STARTING AND STOPPING THE SERVER
   --------------------------------------------------------------------- */

% Tell the server which predicate answers which URL.
:- http_handler(root(.),     home_page,      []).
:- http_handler(root(solve), solve_handler,  []).

show_help :-
    nl,
    write('Tower of Hanoi website loaded.'), nl,
    write('Type  start.  to run the server (then open http://localhost:8080)'), nl,
    write('Type  stop.   to stop it.'), nl, nl.

% start/0 : run the website on the default port 8080.
start :- start(8080).

% start(+Port) : run the website on any port you like.
start(Port) :-
    http_server(http_dispatch, [port(Port)]),
    format("Server running. Open  http://localhost:~d/  in your browser.~n", [Port]),
    format(atom(URL), 'http://localhost:~d/', [Port]),
    ignore(catch(www_open_url(URL), _, true)).    % try to open the browser

% stop/0 : stop the server running on port 8080.
stop :- http_stop_server(8080, []),
        write('Server stopped.'), nl.

/* ---------------------------------------------------------------------
   SECTION 2: HTTP HANDLERS (what the server sends back)
   --------------------------------------------------------------------- */

% home_page(+Request) : sends the HTML page stored in page_line/1 below.
home_page(_Request) :-
    format("Content-type: text/html; charset=UTF-8~n~n"),
    forall(page_line(Line), (write(Line), nl)).

% solve_handler(+Request) : reads ?disks=N, solves the puzzle with Prolog,
% checks the solution against the rules, and answers in JSON.
solve_handler(Request) :-
    http_parameters(Request, [disks(N, [between(1, 10)])]),
    moves(N, a, c, b, Moves),                       % the algorithm
    numlist(1, N, Disks),
    (   apply_moves(Moves, [a-Disks, b-[], c-[]], Final),
        tower(c, Final, Disks)                       % all disks ended on C
    ->  true
    ;   throw(error(system_error(invalid_solution), _))
    ),
    length(Moves, Count),
    format("Content-type: application/json~n~n"),
    format("{\"disks\":~d,\"count\":~d,\"moves\":[", [N, Count]),
    print_moves(Moves),
    write(']}').

% print_moves(+Moves) : writes the moves as a JSON array body.
print_moves([]).
print_moves([M]) :- !, print_move_json(M).
print_moves([M|T]) :- print_move_json(M), write(','), print_moves(T).

print_move_json(move(Disk, From, To)) :-
    upcase_atom(From, F),
    upcase_atom(To, T),
    format("{\"disk\":~d,\"from\":\"~w\",\"to\":\"~w\"}", [Disk, F, T]).

/* ---------------------------------------------------------------------
   SECTION 3: THE TOWER OF HANOI ALGORITHM
   --------------------------------------------------------------------- */

% moves(+N, +From, +To, +Via, -Moves)
% Moves is the list of move(Disk, From, To) that transfers N disks
% from tower From to tower To, using tower Via as the helper.
%
% BASE CASE: zero disks need zero moves.
moves(0, _, _, _, []) :- !.

% RECURSIVE CASE:
%   1) move N-1 disks From -> Via        (To is the helper)
%   2) move the biggest disk From -> To
%   3) move N-1 disks Via -> To          (From is the helper)
moves(N, From, To, Via, Moves) :-
    N > 0,
    N1 is N - 1,
    moves(N1, From, Via, To, Moves1),
    moves(N1, Via, To, From, Moves2),
    append(Moves1, [move(N, From, To)|Moves2], Moves).

/* ---------------------------------------------------------------------
   SECTION 4: RULE CHECKING (so Prolog guarantees the moves are legal)
   --------------------------------------------------------------------- */

% A state is a list like [a-[1,2,3], b-[], c-[]].
% Each tower lists its disks TOP FIRST (disk 1 is the smallest).

% apply_moves(+Moves, +State0, -State) : plays every move in order.
apply_moves([], State, State).
apply_moves([move(D, F, T)|Rest], State0, State) :-
    make_move(D, F, T, State0, State1),
    apply_moves(Rest, State1, State).

% make_move(+Disk, +From, +To, +State0, -State)
% Succeeds only for a LEGAL move: Disk must be on top of tower From and
% must not be placed on a smaller disk.
make_move(Disk, From, To, State0, State) :-
    tower(From, State0, [Disk|FromRest]),
    tower(To, State0, ToStack),
    can_place(Disk, ToStack),
    set_tower(From, FromRest, State0, State1),
    set_tower(To, [Disk|ToStack], State1, State).

% can_place(+Disk, +Stack) : empty tower, or the top disk is larger.
can_place(_, []).
can_place(Disk, [Top|_]) :- Disk < Top.

tower(Name, State, Stack) :- member(Name-Stack, State).

set_tower(Name, New, [Name-_|T], [Name-New|T]) :- !.
set_tower(Name, New, [H|T], [H|T2]) :- set_tower(Name, New, T, T2).

/* ---------------------------------------------------------------------
   SECTION 5: THE WEB PAGE (HTML + CSS + JavaScript)
   Each fact page_line/1 holds one line of the page.
   --------------------------------------------------------------------- */

page_line("<!DOCTYPE html>").
page_line("<html lang='en'>").
page_line("<head>").
page_line("<meta charset='UTF-8'>").
page_line("<meta name='viewport' content='width=device-width, initial-scale=1'>").
page_line("<title>Tower of Hanoi - Prolog Web Game</title>").
page_line("<style>").
page_line("*{box-sizing:border-box}").
page_line("body{margin:0;font-family:Segoe UI,Arial,sans-serif;background:#0f172a;color:#e2e8f0}").
page_line("header{padding:20px;text-align:center;background:#1e293b}").
page_line("h1{margin:0;font-size:1.9rem}").
page_line("h2{margin:0 0 10px;font-size:1.1rem}").
page_line("header p{margin:6px 0 0;color:#94a3b8}").
page_line("main{max-width:1000px;margin:0 auto;padding:16px}").
page_line(".panel{background:#1e293b;border-radius:12px;padding:16px;margin-bottom:16px}").
page_line(".controls{display:flex;flex-wrap:wrap;gap:10px;align-items:center}").
page_line("label{color:#94a3b8}").
page_line("input[type=number]{width:70px;padding:8px;border-radius:8px;border:1px solid #475569;background:#0f172a;color:#e2e8f0}").
page_line("button{padding:9px 14px;border:0;border-radius:8px;background:#38bdf8;color:#0f172a;font-weight:600;cursor:pointer}").
page_line("button.alt{background:#475569;color:#e2e8f0}").
page_line("#status{margin-top:12px;min-height:1.4em;color:#fbbf24;font-weight:600}").
page_line(".stats{color:#94a3b8;margin:0}").
page_line(".board{display:flex;gap:12px;justify-content:space-around}").
page_line(".tw{flex:1;max-width:300px}").
page_line(".tower{height:290px;position:relative;display:flex;flex-direction:column-reverse;align-items:center;border-bottom:8px solid #64748b;cursor:pointer}").
page_line(".tower::before{content:'';position:absolute;left:50%;bottom:0;width:10px;height:100%;margin-left:-5px;background:#64748b;border-radius:5px 5px 0 0}").
page_line(".tower.sel{outline:3px solid #38bdf8;outline-offset:4px}").
page_line(".lbl{text-align:center;margin-top:8px;color:#94a3b8;font-weight:600}").
page_line(".disk{height:22px;margin-top:2px;border-radius:6px;position:relative;z-index:1;color:#0f172a;font-weight:700;font-size:13px;line-height:22px;text-align:center}").
page_line(".grid2{display:grid;grid-template-columns:1fr 1fr;gap:16px}").
page_line("@media (max-width:700px){.grid2{grid-template-columns:1fr}}").
page_line("#log{list-style:none;margin:0;padding:0;max-height:220px;overflow-y:auto;font-family:Consolas,monospace;font-size:.9rem}").
page_line("#log li{padding:3px 0;border-bottom:1px solid #334155}").
page_line("ol{margin:0;padding-left:20px;line-height:1.7}").
page_line("</style>").
page_line("</head>").
page_line("<body>").
page_line("<header><h1>Tower of Hanoi</h1><p>A web game powered by Prolog</p></header>").
page_line("<main>").
page_line("<div class='panel'>").
page_line("<div class='controls'>").
page_line("<label for='n'>Number of disks (1-10):</label>").
page_line("<input id='n' type='number' min='1' max='10' value='3'>").
page_line("<button id='bNew'>New Game</button>").
page_line("<button id='bSolve'>Auto Solve (Prolog)</button>").
page_line("<button id='bPause' class='alt'>Pause</button>").
page_line("<button id='bStep' class='alt'>Next Step</button>").
page_line("<label for='spd'>Speed</label>").
page_line("<input id='spd' type='range' min='1' max='10' value='6'>").
page_line("</div>").
page_line("<div id='status'></div>").
page_line("<p class='stats'>Moves made: <b id='cnt'>0</b> | Minimum possible: <b id='min'>7</b></p>").
page_line("</div>").
page_line("<div class='panel'><div class='board' id='board'></div></div>").
page_line("<div class='grid2'>").
page_line("<div class='panel'><h2>Move log</h2><ul id='log'></ul></div>").
page_line("<div class='panel'><h2>How to play</h2>").
page_line("<ol>").
page_line("<li>Move only one disk at a time.</li>").
page_line("<li>Only the top disk of a tower can be moved.</li>").
page_line("<li>Never place a larger disk on a smaller disk.</li>").
page_line("<li>Goal: move all disks from tower A to tower C.</li>").
page_line("</ol>").
page_line("<p class='stats'>Play by hand: click a tower to pick its top disk, then click the destination tower. Or press Auto Solve to watch the solution Prolog calculates.</p>").
page_line("</div>").
page_line("</div>").
page_line("</main>").
page_line("<script>").
page_line("var N=3,towers={A:[],B:[],C:[]},moves=[],idx=0,timer=null,selected=null,count=0,auto=false;").
page_line("function el(id){return document.getElementById(id);}").
page_line("function say(msg){el('status').textContent=msg;}").
page_line("function draw(){").
page_line(" ['A','B','C'].forEach(function(t){").
page_line("  var box=el('t'+t);").
page_line("  box.innerHTML='';").
page_line("  box.className=(selected===t)?'tower sel':'tower';").
page_line("  towers[t].forEach(function(d){").
page_line("   var div=document.createElement('div');").
page_line("   div.className='disk';").
page_line("   div.style.width=(22+78*d/N)+'%';").
page_line("   div.style.background='hsl('+Math.round(d*300/(N+1))+',70%,60%)';").
page_line("   div.textContent=d;").
page_line("   box.appendChild(div);").
page_line("  });").
page_line(" });").
page_line(" el('cnt').textContent=count;").
page_line(" el('min').textContent=Math.pow(2,N)-1;").
page_line("}").
page_line("function addLog(n,d,f,t){").
page_line(" var li=document.createElement('li');").
page_line(" li.textContent='Move '+n+': disk '+d+' from '+f+' to '+t;").
page_line(" var log=el('log');").
page_line(" log.appendChild(li);").
page_line(" log.scrollTop=log.scrollHeight;").
page_line("}").
page_line("function stop(){if(timer){clearInterval(timer);timer=null;}}").
page_line("function newGame(){").
page_line(" stop();").
page_line(" var v=parseInt(el('n').value,10);").
page_line(" if(isNaN(v)||v<1||v>10){say('Please enter a whole number from 1 to 10.');return false;}").
page_line(" N=v;towers={A:[],B:[],C:[]};").
page_line(" for(var i=N;i>=1;i--){towers.A.push(i);}").
page_line(" moves=[];idx=0;count=0;selected=null;auto=false;").
page_line(" el('log').innerHTML='';").
page_line(" el('bPause').textContent='Pause';").
page_line(" say('New game started. Click a tower to pick its top disk.');").
page_line(" draw();").
page_line(" return true;").
page_line("}").
page_line("function tryMove(f,to){").
page_line(" if(f===to){return 'Choose a different tower.';}").
page_line(" var src=towers[f],dst=towers[to];").
page_line(" if(src.length===0){return 'Tower '+f+' is empty.';}").
page_line(" var d=src[src.length-1];").
page_line(" if(dst.length>0&&dst[dst.length-1]<d){return 'Illegal move! Disk '+d+' cannot go on smaller disk '+dst[dst.length-1]+'.';}").
page_line(" src.pop();dst.push(d);count++;").
page_line(" addLog(count,d,f,to);").
page_line(" draw();").
page_line(" return '';").
page_line("}").
page_line("function checkWin(){").
page_line(" if(towers.C.length===N){say('Solved in '+count+' moves! Minimum possible is '+(Math.pow(2,N)-1)+'.');return true;}").
page_line(" return false;").
page_line("}").
page_line("function clickTower(t){").
page_line(" if(auto){say('Auto Solve is active. Press New Game to play by hand.');return;}").
page_line(" if(selected===null){").
page_line("  if(towers[t].length===0){say('Tower '+t+' is empty.');return;}").
page_line("  selected=t;say('Tower '+t+' selected. Now click the destination tower.');draw();return;").
page_line(" }").
page_line(" var f=selected;selected=null;").
page_line(" say(tryMove(f,t));").
page_line(" draw();").
page_line(" checkWin();").
page_line("}").
page_line("function stepOnce(){").
page_line(" if(idx>=moves.length){stop();auto=false;checkWin();return;}").
page_line(" var m=moves[idx++];").
page_line(" var err=tryMove(m.from,m.to);").
page_line(" if(err){stop();say('Error: '+err);return;}").
page_line(" if(idx>=moves.length){stop();auto=false;checkWin();}").
page_line(" else{say('Move '+idx+' of '+moves.length);}").
page_line("}").
page_line("function delay(){return 1100-el('spd').value*100;}").
page_line("function play(){stop();if(auto){timer=setInterval(stepOnce,delay());}}").
page_line("function solve(){").
page_line(" if(!newGame()){return;}").
page_line(" say('Asking Prolog for the solution...');").
page_line(" fetch('/solve?disks='+N).then(function(r){").
page_line("  if(!r.ok){throw new Error('server error '+r.status);}").
page_line("  return r.json();").
page_line(" }).then(function(data){").
page_line("  moves=data.moves;idx=0;auto=true;").
page_line("  say('Prolog found '+data.count+' moves. Playing...');").
page_line("  play();").
page_line(" }).catch(function(e){say('Could not reach the Prolog server: '+e.message);});").
page_line("}").
page_line("function init(){").
page_line(" var b=el('board');").
page_line(" ['A','B','C'].forEach(function(t){").
page_line("  var w=document.createElement('div');w.className='tw';").
page_line("  var box=document.createElement('div');box.className='tower';box.id='t'+t;").
page_line("  box.onclick=function(){clickTower(t);};").
page_line("  var l=document.createElement('div');l.className='lbl';l.textContent='Tower '+t;").
page_line("  w.appendChild(box);w.appendChild(l);b.appendChild(w);").
page_line(" });").
page_line(" el('bNew').onclick=newGame;").
page_line(" el('bSolve').onclick=solve;").
page_line(" el('bPause').onclick=function(){").
page_line("  if(!auto){return;}").
page_line("  if(timer){stop();this.textContent='Resume';say('Paused.');}").
page_line("  else{this.textContent='Pause';play();}").
page_line(" };").
page_line(" el('bStep').onclick=function(){").
page_line("  if(!auto||idx>=moves.length){say('Press Auto Solve first.');return;}").
page_line("  stop();el('bPause').textContent='Resume';stepOnce();").
page_line(" };").
page_line(" el('spd').oninput=function(){if(timer){play();}};").
page_line(" newGame();").
page_line("}").
page_line("init();").
page_line("</script>").
page_line("</body>").
page_line("</html>").
