import java.util.ArrayList;
import processing.net.*;

static final int WIDTH = 640;
static final int HEIGHT = 480;
static final int INPUT_BUFFER_SIZE = 1000;
static final int WIN_SCORE = 5;

// Networking
Server server;
Client client;

// Global time variable
int time = 0;

int ballX, ballY, ballSpeedX, ballSpeedY;
int player1Y, player2Y;
int playerSpeed = 5;
int paddleWidth = 10;
int paddleHeight = 80;
int paddleDist = 40;
int ballSize = 20;

boolean isHost = true;  // True if this instance is the host

int input1 = 0;
int input2 = 0;

int score1 = 0;
int score2 = 0;

long startTime = 0;

// 0 - Menu
// 1 - Playing
// 2 - Player 1 Win
// 3 - Player 2 Win
// 4 - Waiting for connection
// 5 - Countdown
int gameState = 0;

int framesBack = 10;

// History buffer for rollback
ArrayList<GameState> stateHistory = new ArrayList<GameState>();

ArrayList<Integer> userInputs = new ArrayList<Integer>(INPUT_BUFFER_SIZE);
ArrayList<Integer> predictedInputs = new ArrayList<Integer>(INPUT_BUFFER_SIZE);

// Class to represent the game state at a given frame
class GameState {
  int time;
  boolean confirmed;
  int ballX, ballY;
  int player1Y, player2Y;
  
  GameState(int t, boolean con, int bx, int by, int p1Y, int p2Y) {
    time = t;
    confirmed = con;
    ballX = bx;
    ballY = by;
    player1Y = p1Y;
    player2Y = p2Y;
  }
}

// Called once
void setup() {
  size(640, 480);
  
  // Initalize predictions to 0
  for(int i = 0; i < INPUT_BUFFER_SIZE; i++) {
    userInputs.add(0);
    predictedInputs.add(0); 
  }
}

// Called when a client connects
void serverEvent(Server someServer, Client someClient) {
  if (isHost) {
    // Send start time to the client
    startTime = System.currentTimeMillis() + 5000;
    server.write(startTime + "\n");
    gameState = 5;
  }
}

// Called every frame
void draw() {
  background(0);
  
  // Wait for the start time before drawing anything
  if (gameState == 0) {
    textSize(40);
    text("Rollback Pong", 50, HEIGHT/2, WIDTH, HEIGHT);
    textSize(20);
    text("By Nicholas Buckley, Haig Emirzian, and Jason Qiu", 50, HEIGHT/2 + 50, WIDTH, HEIGHT);

    // Host Button
    fill(125);
    rect(50, HEIGHT/2+100, 100, 40);
    textSize(20);
    fill(255);
    text("Host", 65, HEIGHT/2+115, 50, 30);

    // Connect Button
    fill(125);
    rect(175, HEIGHT/2+100, 100, 40);
    textSize(20);
    fill(255);
    text("Connect", 190, HEIGHT/2+115, 100, 30);

    return;
  }
  else if (gameState == 4) {
    if (isHost) { // Host
      textSize(40);
      text("You are currently hosting a game", 50, HEIGHT/2, WIDTH, HEIGHT);
      textSize(20);
      text("Waiting for a peer to connect...", 50, HEIGHT/2 + 50, WIDTH, HEIGHT);

      fill(125);
      rect(50, HEIGHT/2+100, 100, 40);
      textSize(20);
      stroke(255);
      fill(255);
      text("Cancel", 65, HEIGHT/2+115, 100, 40);
    } else { // Start Client

      if (client.available() != 0) {
        startTime = Long.parseLong(client.readString().trim());
        gameState = 5;
        return;
      }

      textSize(40);
      text("Attempting to join a hosted game", 50, HEIGHT/2, WIDTH, HEIGHT);
      textSize(20);
      text("Host may not exist", 50, HEIGHT/2 + 50, WIDTH, HEIGHT);

      fill(125);
      rect(50, HEIGHT/2+100, 100, 40);
      textSize(20);
      stroke(255);
      fill(255);
      text("Cancel", 65, HEIGHT/2+115, 100, 40);
    }

    return;
  }
  else if (gameState == 5) {
    if (System.currentTimeMillis() < startTime) { // Continue waiting
      textSize(50);
      text((int)((startTime - System.currentTimeMillis())/1000.0f) + 1 + "", WIDTH/2, HEIGHT/2, WIDTH/2, HEIGHT/2);  // Text wraps within text box
      return;
    }
    else if (startTime > 0){ // Start the game
      gameState = 1;
      time = 0;
      resetGame();
    }
  }
  else if (gameState == 2) { // Game is over and Player 1 won
    textSize(40);
    text("Player 1 Wins!", 50, HEIGHT/2, WIDTH, HEIGHT);
    textSize(20);
    text("Thank you for playing", 50, HEIGHT/2 + 50, WIDTH, HEIGHT);

    // Host Button
    fill(125);
    rect(50, HEIGHT/2+100, 100, 40);
    textSize(20);
    fill(255);
    text("Menu", 65, HEIGHT/2+115, 50, 30);
    return;
  }
  else if (gameState == 3) { // Game is over and Player 2 won
    text("Player 2 Wins!", 50, HEIGHT/2, WIDTH, HEIGHT);
    textSize(20);
    text("Thank you for playing", 50, HEIGHT/2 + 50, WIDTH, HEIGHT);

    // Host Button
    fill(125);
    rect(50, HEIGHT/2+100, 100, 40);
    textSize(20);
    fill(255);
    text("Menu", 65, HEIGHT/2+115, 50, 30);
    return;
  }

  // ----- Retrieve Remote inputs -----
  // Host: read from socket
  if (isHost && server.available() != null) {
    Client thisClient = server.available();
    String data = thisClient.readString();

    if (data != null) {
      print("Got remote intput: " + data);
      ArrayList<Integer[]> remoteInput = parseInput(data);
      handleRemoteInput(remoteInput);  // Apply remote inputs from client
    }
  }
  // Networking - Client
  else if (!isHost && client.available() > 0) {
    String data = client.readString();
    
    if (data != null) {
      println("Got remote intput: " + data);
      ArrayList<Integer[]> remoteInput = parseInput(data);
      handleRemoteInput(remoteInput);  // Apply remote inputs from host
    }
  }
  
  // ----- Get inputs -----
  // Get current player
  if (keyPressed) {
    if (key == 'w') {
      userInputs.set((time + framesBack) % INPUT_BUFFER_SIZE, -1);
      sendLocalInput(time, -1);
    } 
    else if (key == 's') {
      userInputs.set((time + framesBack) % INPUT_BUFFER_SIZE, 1);
      sendLocalInput(time, 1);
    }
  }
  else {
    sendLocalInput(time, 0);
  }
  
  // Get other player
  if (isHost) {
    input1 = userInputs.get(time % INPUT_BUFFER_SIZE);
    input2 = predictedInputs.get(time % INPUT_BUFFER_SIZE);
  }
  else {
    input1 = predictedInputs.get(time % INPUT_BUFFER_SIZE);
    input2 = userInputs.get(time % INPUT_BUFFER_SIZE);
  }

  // Reset past values to 0
  userInputs.set(time % INPUT_BUFFER_SIZE, 0);
  predictedInputs.set(time % INPUT_BUFFER_SIZE, 0);
  
  // ----- Update Game -----
  updateGame();
  
  // ----- Render -----
  // Draw Score
  text(score1 + "  " + score2, WIDTH/2 - 20, 10, WIDTH/2, HEIGHT/2);
  
  // Draw ball
  ellipse(ballX, ballY, ballSize, ballSize);
  
  // Draw paddles
  rect(paddleDist, player1Y, paddleWidth, paddleHeight);
  rect(width - paddleDist, player2Y, paddleWidth, paddleHeight);
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
}

// Parse input data from remote
ArrayList<Integer[]> parseInput(String data) {
  ArrayList<Integer[]> results = new ArrayList<Integer[]>();
  String[] parts = data.trim().split(",");
  
  for(int i = 0; i * 2 < parts.length - 1; i += 2) {
    results.add(new Integer[] {Integer.parseInt(parts[2*i].trim()), Integer.parseInt(parts[2*i+1].trim())});
  }

  return results;
}

void handleRemoteInput(ArrayList<Integer[]> remoteInputs) {
  for(Integer[] remoteInput : remoteInputs) {
    int t = remoteInput[0];
    int newInput = remoteInput[1];
    int oldInput = predictedInputs.get((t + framesBack) % INPUT_BUFFER_SIZE);
    
    if (oldInput != newInput) {
      predictedInputs.set((t + framesBack) % INPUT_BUFFER_SIZE, newInput);  
      
      if ((time + framesBack) < t)
        rollbackTo(stateHistory.get(t));
    }
  }
}

// Send local input to remote client/host
void sendLocalInput(int time, int i) {
  String input = time + "," + i + ",";
  if (isHost) {
    server.write(input + "\n");
  } else {
    client.write(input + "\n");
  }
}

void updateGame() {
  // Update ball position
  ballX += ballSpeedX;
  ballY += ballSpeedY;

  if (ballY - ballSize/2 <= 0 || ballY + ballSize/2 >= height) {
    ballSpeedY *= -1;
  }

  player1Y += playerSpeed * input1;
  player2Y += playerSpeed * input2;
  
  // Ball collision with paddles
  if (ballX <= paddleDist + paddleWidth && ballY > player1Y && ballY < player1Y + paddleHeight) {
    ballSpeedX *= -1;
  }
  
  if (ballX >= width - paddleDist - paddleWidth && ballY > player2Y && ballY < player2Y + paddleHeight) {
    ballSpeedX *= -1;
  }
  
  // Ball outside of screen
  if (ballX < 0) {
     score2++;
     resetGame(); 
  }
  else if (ballX > width) {
    score1++;
    resetGame(); 
  }

  // Check if there is a winner
  if (score1 >= WIN_SCORE) {
    gameState = 2;
    score1 = 0;
  }
  else if (score2 >= WIN_SCORE){
    gameState = 3;
    score2 = 0;
  }
  
  saveGameState();
  time++;
}

// Save the current game state
void saveGameState() {
  stateHistory.add(new GameState(time, false, ballX, ballY, player1Y, player2Y));
} 

// Tracks button clicks
void mousePressed() {
  // Menu Buttons
  if (gameState == 0) {
    // Host Button
    if (mouseX >= 50 && mouseX <= 150 && mouseY >= HEIGHT/2+100 && mouseY <= HEIGHT/2+140) {
      isHost = true;
      server = new Server(this, 5201);
      gameState = 4;
    }

    // Connect Button
    if (mouseX >= 175 && mouseX <= 275 && mouseY >= HEIGHT/2+100 && mouseY <= HEIGHT/2+140) {
      isHost = false;
      gameState = 4;
      client = new Client(this, "127.0.0.1", 5201);
    }
  }

  // Waiting for Connection Buttons
  else if (gameState == 4) {
    if (mouseX >= 50 && mouseX <= 150 && mouseY >= HEIGHT/2+100 && mouseY <= HEIGHT/2+140) {
      gameState = 0;
      if (isHost)
        server.stop();
      else 
        client.stop();
    }
  }

  else if (gameState == 2) {
    if (mouseX >= 50 && mouseX <= 150 && mouseY >= HEIGHT/2+100 && mouseY <= HEIGHT/2+140) {
      gameState = 0;
      if (isHost)
        server.stop();
      else 
        client.stop();
    }
  }
}