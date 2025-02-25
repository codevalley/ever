// ignore_for_file: avoid_print

import 'dart:io';

void main() {
  // Display ASCII art
  print('''
\x1B[33m
  _______ _        _____      _______ _    _ _______ _______ 
 |       | |      |     |    |       |  \\ | |       |       |
 |       | |      |     |    |    ___|   \\| |    ___|  _____|
 |       | |      |     |    |   |___|    \\ |   |___| |_____ 
 |      _| |      |     |___ |    ___|     \\|    ___|_____  |
 |     |_| |_____ |         ||   |___|\\     \\   |___ _____| |
 |_______|_______|\\_______/ |_______|\\____/|_______|_______|
                                                
\x1B[0m''');
  
  // Display welcome message in a box
  printBox('Welcome to CLI-EVER!', '\x1B[36m');
  
  // Display API URL
  print('API URL: ${Platform.environment['EVER_API_URL'] ?? 'Default API'}');
  print('');
  
  // Display available commands in a box
  printBox('Available Commands', '\x1B[33m');
  
  // List some example commands
  print(' - \x1B[32mhelp\x1B[0m: Display help information');
  print(' - \x1B[32mlogin\x1B[0m: Login to your account');
  print(' - \x1B[32mlogout\x1B[0m: Logout current user');
  print(' - \x1B[32mnote\x1B[0m: Note management commands');
  print(' - \x1B[32mtask\x1B[0m: Task management commands');
  
  print('');
  
  // Display tips in a box
  printBox('Tips', '\x1B[32m');
  
  print(' - Type "help" to see available commands');
  print(' - Type "exit" or "quit" to exit');
  print('');
  
  // Interactive prompt
  while (true) {
    stdout.write('ever> ');
    final input = stdin.readLineSync();
    
    if (input == null || input.isEmpty) {
      continue;
    }
    
    if (input.toLowerCase() == 'exit' || input.toLowerCase() == 'quit') {
      print('Goodbye!');
      break;
    }
    
    print('You entered: $input');
  }
}

/// Print a simple box with a title
void printBox(String title, String color) {
  final width = 60;
  final padding = ' ' * ((width - title.length) ~/ 2);
  final extraSpace = (width - title.length) % 2 != 0 ? ' ' : '';
  
  print('$color+${'-' * width}+');
  print('|$padding$title$padding$extraSpace|');
  print('+${'-' * width}+\x1B[0m');
  print('');
} 