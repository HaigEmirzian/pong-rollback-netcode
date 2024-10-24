import java.util.ArrayList;
import processing.net.*;

// Networking
Server server;
Client client;

int time = 0;

int ballX, ballY, ballSpeedX, ballSpeedY;
int player1Y, player2Y;
int playerSpeed = 5;
int paddleWidth = 10, paddleHeight = 80;
int ballSize = 20;
boolean isServer = true;  // True if this instance is the server

int input1 = 0;
int input2 = 0;

long startTime = 0;
boolean playing = false;

// History buffer for rollback
ArrayList<GameState> stateHistory = new ArrayList<GameState>();
int maxHistory = 50000;  // Keep the last 10 states

void setup() {
  size(640, 480);

  
  if (isServer) {
    // Start server on port 5200
    server = new Server(this, 5201);
  } else {
    // Connect to server
    client = new Client(this, "127.0.0.1", 5201);  

    while (client.available() == 0) { continue; }
    startTime = Long.parseLong(client.readString().trim());
  }
  //resetGame();
}

void rollbackTo(GameState oldState) {
  // Rollback to a previous state
  time = oldState.time;
  ballX = oldState.ballX;
  ballY = oldState.ballY;
  player1Y = oldState.player1Y;
  player2Y = oldState.player2Y;
}

void resetGame() {
  ballX = width / 2;
  ballY = height / 2;
  ballSpeedX = 2;
  ballSpeedY = 2;
  
  player1Y = height / 2 - paddleHeight / 2;
  player2Y = height / 2 - paddleHeight / 2;
  
  // Initialize game state history
  //time = 0;
  //stateHistory.clear();
  stateHistory.add(new GameState(time, true, 0, 0, ballX, ballY, player1Y, player2Y));
  
  updatePredictions(0);
  println("Size: " + stateHistory.size());
}

void draw() {
  background(0);
  
  if (!playing) {
    if (System.currentTimeMillis() < startTime) {
      println(System.currentTimeMillis() - startTime + "");
      return;
    }
    else if (startTime > 0){
      playing = true;
      time = 0;
      resetGame();
    }
  }
  
    // Display game
  displayGame();
  updateGame();
  
  // Networking - Server
  if (isServer && server.available() != null) {
    Client thisClient = server.available();
    String data = thisClient.readString();
    if (data != null) {
      print("Got remote intput: " + data);
      
      int[] remoteInput = parseInput(data);
      handleRemoteInput(remoteInput);  // Apply remote inputs from client
    }
  }

  // Networking - Client
  if (!isServer && client.available() > 0) {
    String data = client.readString();
    if (data != null) {
      println("Got remote intput: " + data);
      
      int[] remoteInput = parseInput(data);
      handleRemoteInput(remoteInput);  // Apply remote inputs from server
    }
  }
  //handleRollback();

  // Send inputs (both clients and server send their local inputs)
  //sendLocalInput();
}

void displayGame() {
  // Draw ball
  ellipse(ballX, ballY, ballSize, ballSize);
  
  // Draw paddles
  rect(30, player1Y, paddleWidth, paddleHeight);
  rect(width - 50, player2Y, paddleWidth, paddleHeight);
}

void updateGame() {
  // Update ball position
  ballX += ballSpeedX;
  ballY += ballSpeedY;
  
  input1 = 0;
  input2 = 0;
  
  if (ballY <= 0 || ballY >= height) {
    ballSpeedY *= -1;
  }
  
  // Paddle movement
  if (keyPressed) {
    if (key == 'w') {
      if (isServer) {
        //player1Y -= playerSpeed;
        input1 = -1;
      }
      else {
        //player2Y -= playerSpeed;
        input2 = -1;
      }
       
      sendLocalInput(time, -1);
    } 
    else if (key == 's') {
      if (isServer) {
        //player1Y += playerSpeed;
        input1 = 1;
      }
      else {
        //player2Y += playerSpeed;
        input2 = 1;
      }
      
      sendLocalInput(time, 1);
    }
  }
  else {
    if (isServer) {
        input1 = 0;
      }
      else {
         input2 = 0; 
      }
      
      sendLocalInput(time, 0);
  }
    
  //sendLocalInput(time, 0);
    
  if (time > 0) {
    if (isServer) {
      input2 = stateHistory.get(time - 1).input2;
    }
    else {
      input1 = stateHistory.get(time - 1).input1;
    }
  }

  player1Y += playerSpeed * input1;
  player2Y += playerSpeed * input2;
  
  // Ball collision with paddles
  if (ballX <= 40 && ballY > player1Y && ballY < player1Y + paddleHeight) {
    ballSpeedX *= -1;
  }
  
  if (ballX >= width - 40 && ballY > player2Y && ballY < player2Y + paddleHeight) {
    ballSpeedX *= -1;
  }
  
  // Ball outside of screen
  if (ballX < 0 || ballX > width) {
     resetGame(); 
  }
  
  saveGameState(input1, input2);

  if(isServer) {
    updatePredictions(input2); 
  }  
  else {
    updatePredictions(input1); 
  }
  
  time++;
}

void updatePredictions(int input) {
  // Create predictions
  for(int i = 1; i < 10; i++) {
    if (isServer) {
      if (stateHistory.size() <= time + i) {
        stateHistory.add(new GameState(time+i, false, 0, input, 0, 0, 0, 0));
      }
      else if (!stateHistory.get(time+i).confirmed){
        stateHistory.set(time+i, new GameState(time+i, false, 0, input, 0, 0, 0, 0));
      }
    }
    else {
      if (stateHistory.size() <= time + i) {
        stateHistory.add(new GameState(time+i, false, input, 0, 0, 0, 0, 0));
      }
      else {
        stateHistory.set(time+i, new GameState(time+i, false, input, 0, 0, 0, 0, 0));
      }
    }
  } 
}

void saveGameState(int input1, int input2) {
  // Save the current game state
  if (time < stateHistory.size()) {
    stateHistory.set(time, new GameState(time, false, input1, input2, ballX, ballY, player1Y, player2Y));
  }
  else {
    stateHistory.add(new GameState(time, false, input1, input2, ballX, ballY, player1Y, player2Y));
  }
  
  // Keep history size limited
  if (stateHistory.size() > maxHistory) {
    stateHistory.remove(0);
  }
}

// Send local input to remote client/server
void sendLocalInput(int time, int i) {
  String input = time + "," + i;
  if (isServer) {
    server.write(input + "\n");
  } else {
    client.write(input + "\n");
  }
}

// Parse input data from remote
int[] parseInput(String data) {
  String[] parts = data.trim().split(",");
  int[] inputs = new int[2];
  inputs[0] = int(parts[0]);  // Remote time
  inputs[1] = int(parts[1]);  // Remote player position
  println(inputs);
  return inputs;
}

// Handle remote inputs
void handleRemoteInput(int[] remoteInput) {
  int _time = remoteInput[0];
  int input = remoteInput[1];
  
  println("Looking for: " + _time + " in range: "  + stateHistory.get(0).time + ", " + stateHistory.get(stateHistory.size() - 1).time);
   
   //if (stateHistory.get(0).time < _time) {
    //_time = stateHistory.get(0).time;
   //}
   
  for(int i = 0; i < stateHistory.size(); i++) {
    GameState curState = stateHistory.get(i);
    print(" " + curState.time);
    
    if (curState.time == _time) {
      println("");
      println("Found that to compare");
      //if (!curState.confirmed) {
        curState.confirmed = true;
        
        println("Not confirmed");
        
        if (isServer) {
          println("Guess: " + curState.input2 + ", Real: " + input);
          if (curState.input2 != input) {
             curState.input2 = input;
             println("Input guessed wrong. Rollback");
             rollbackTo(curState);
             
             updatePredictions(input2);
          }
        }
        else {
          println("Guess: " + curState.input1 + ", Real: " + input);
          if (curState.input1 != input) {
             curState.input1 = input;
             println("Input guessed wrong. Rollback");
             rollbackTo(curState);
             
             updatePredictions(input1);
          }
        }
        
        //stateHistory.subList(i+1, stateHistory.size()).clear(); 
        
      //}else {
       // println("Already confirmed");
      //}
      break;
    } 
  }
}

// Class to represent the game state at a given frame
class GameState {
  int time;
  boolean confirmed;
  int input1, input2;
  int ballX, ballY;
  int player1Y, player2Y;
  
  GameState(int t, boolean con, int i1, int i2, int bx, int by, int p1Y, int p2Y) {
    time = t;
    confirmed = con;
    input1 = i1;
    input2 = i2;
    ballX = bx;
    ballY = by;
    player1Y = p1Y;
    player2Y = p2Y;
  }
}

void serverEvent(Server someServer, Client someClient) {
  if (isServer) {
    println("We have a new client: " + someClient.ip());
    //play = true;
    //resetGame();
    startTime = System.currentTimeMillis() + 5000;
    server.write(startTime + "\n");
  }
}