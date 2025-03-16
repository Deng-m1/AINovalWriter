import 'dart:async';

import 'package:ainoval/services/auth_service.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

// 认证事件
abstract class AuthEvent extends Equatable {
  const AuthEvent();
  
  @override
  List<Object?> get props => [];
}

// 初始化认证事件
class AuthInitialize extends AuthEvent {}

// 登录事件
class AuthLogin extends AuthEvent {
  
  const AuthLogin({required this.username, required this.password});
  final String username;
  final String password;
  
  @override
  List<Object?> get props => [username, password];
}

// 注册事件
class AuthRegister extends AuthEvent {
  
  const AuthRegister({
    required this.username, 
    required this.password, 
    required this.email,
    this.displayName,
  });
  final String username;
  final String password;
  final String email;
  final String? displayName;
  
  @override
  List<Object?> get props => [username, password, email, displayName];
}

// 登出事件
class AuthLogout extends AuthEvent {}

// 认证状态
abstract class AuthState extends Equatable {
  const AuthState();
  
  @override
  List<Object?> get props => [];
}

// 初始状态
class AuthInitial extends AuthState {}

// 认证中状态
class AuthLoading extends AuthState {}

// 已认证状态
class AuthAuthenticated extends AuthState {
  
  const AuthAuthenticated({required this.userId, required this.username});
  final String userId;
  final String username;
  
  @override
  List<Object?> get props => [userId, username];
}

// 未认证状态
class AuthUnauthenticated extends AuthState {}

// 认证错误状态
class AuthError extends AuthState {
  
  const AuthError({required this.message});
  final String message;
  
  @override
  List<Object?> get props => [message];
}

// 认证Bloc
class AuthBloc extends Bloc<AuthEvent, AuthState> {
  
  AuthBloc({required AuthService authService}) 
      : _authService = authService,
        super(AuthInitial()) {
    on<AuthInitialize>(_onInitialize);
    on<AuthLogin>(_onLogin);
    on<AuthRegister>(_onRegister);
    on<AuthLogout>(_onLogout);
    
    // 监听认证服务的状态变化
    _authStateSubscription = _authService.authStateStream.listen((authState) {
      if (authState.isAuthenticated) {
        add(AuthInitialize());
      } else if (authState.error != null) {
        emit(AuthError(message: authState.error!));
      } else {
        emit(AuthUnauthenticated());
      }
    });
  }
  final AuthService _authService;
  StreamSubscription? _authStateSubscription;
  
  Future<void> _onInitialize(AuthInitialize event, Emitter<AuthState> emit) async {
    final currentState = _authService.currentState;
    
    if (currentState.isAuthenticated) {
      emit(AuthAuthenticated(
        userId: currentState.userId,
        username: currentState.username,
      ));
    } else {
      emit(AuthUnauthenticated());
    }
  }
  
  Future<void> _onLogin(AuthLogin event, Emitter<AuthState> emit) async {
    emit(AuthLoading());
    
    try {
      final result = await _authService.login(event.username, event.password);
      
      if (result.isAuthenticated) {
        emit(AuthAuthenticated(
          userId: result.userId,
          username: result.username,
        ));
      } else {
        emit(AuthError(message: result.error ?? '登录失败'));
      }
    } catch (e) {
      emit(AuthError(message: e.toString()));
    }
  }
  
  Future<void> _onRegister(AuthRegister event, Emitter<AuthState> emit) async {
    emit(AuthLoading());
    
    try {
      final result = await _authService.register(
        event.username, 
        event.password, 
        event.email,
        displayName: event.displayName,
      );
      
      if (result.isAuthenticated) {
        emit(AuthAuthenticated(
          userId: result.userId,
          username: result.username,
        ));
      } else {
        emit(AuthError(message: result.error ?? '注册失败'));
      }
    } catch (e) {
      emit(AuthError(message: e.toString()));
    }
  }
  
  Future<void> _onLogout(AuthLogout event, Emitter<AuthState> emit) async {
    emit(AuthLoading());
    
    try {
      await _authService.logout();
      emit(AuthUnauthenticated());
    } catch (e) {
      emit(AuthError(message: e.toString()));
    }
  }
  
  @override
  Future<void> close() {
    _authStateSubscription?.cancel();
    return super.close();
  }
} 