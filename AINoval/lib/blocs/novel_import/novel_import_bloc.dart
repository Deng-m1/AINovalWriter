import 'dart:async';

import 'package:ainoval/models/import_status.dart';
import 'package:ainoval/services/api_service/repositories/novel_repository.dart';
import 'package:ainoval/utils/logger.dart';
import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:file_picker/file_picker.dart';

part 'novel_import_event.dart';
part 'novel_import_state.dart';

/// 小说导入Bloc
class NovelImportBloc extends Bloc<NovelImportEvent, NovelImportState> {
  /// 创建小说导入Bloc
  NovelImportBloc({required this.novelRepository})
      : super(NovelImportInitial()) {
    on<ImportNovelFile>(_onImportNovelFile);
    on<ImportStatusUpdate>(_onImportStatusUpdate);
    on<ResetImportState>(_onResetImportState);
  }

  /// 小说仓库
  final NovelRepository novelRepository;

  /// 导入状态订阅
  StreamSubscription<ImportStatus>? _importStatusSubscription;

  /// 处理导入小说文件事件
  Future<void> _onImportNovelFile(
      ImportNovelFile event, Emitter<NovelImportState> emit) async {
    emit(NovelImportInProgress(status: 'PREPARING', message: '准备中...'));

    try {
      // 选择文件
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['txt'],
        withData: true,
      );

      if (result == null || result.files.isEmpty) {
        emit(NovelImportInitial());
        return;
      }

      final file = result.files.first;
      final fileBytes = file.bytes;
      final fileName = file.name;

      if (fileBytes == null) {
        emit(NovelImportFailure(message: '无法读取文件数据'));
        return;
      }

      emit(NovelImportInProgress(status: 'UPLOADING', message: '上传中...'));

      // 上传文件并获取任务ID
      final jobId = await novelRepository.importNovel(fileBytes, fileName);

      emit(NovelImportInProgress(
          status: 'PROCESSING', message: '处理中...', jobId: jobId));

      // 订阅导入状态更新
      _importStatusSubscription?.cancel();
      _importStatusSubscription = novelRepository.getImportStatus(jobId).listen(
        (importStatus) {
          add(ImportStatusUpdate(
            status: importStatus.status,
            message: importStatus.message,
            jobId: jobId,
          ));
        },
        onError: (error) {
          AppLogger.e('NovelImportBloc', '监听导入状态流错误', error);
          add(ImportStatusUpdate(
            status: 'FAILED',
            message: '监听导入状态失败: ${error.toString()}',
            jobId: jobId,
          ));
        },
        onDone: () {
          AppLogger.i('NovelImportBloc', '导入状态流已关闭');
        },
      );
    } catch (e) {
      AppLogger.e('NovelImportBloc', '导入小说失败', e);
      emit(NovelImportFailure(message: '导入失败: ${e.toString()}'));
    }
  }

  /// 处理导入状态更新事件
  void _onImportStatusUpdate(
      ImportStatusUpdate event, Emitter<NovelImportState> emit) {
    if (event.status == 'COMPLETED') {
      emit(NovelImportSuccess(message: event.message));
      _importStatusSubscription?.cancel();
      _importStatusSubscription = null;
    } else if (event.status == 'FAILED' || event.status == 'ERROR') {
      emit(NovelImportFailure(message: event.message));
      _importStatusSubscription?.cancel();
      _importStatusSubscription = null;
    } else {
      emit(NovelImportInProgress(
        status: event.status,
        message: event.message,
        jobId: event.jobId,
      ));
    }
  }

  /// 重置导入状态
  void _onResetImportState(
      ResetImportState event, Emitter<NovelImportState> emit) {
    _importStatusSubscription?.cancel();
    _importStatusSubscription = null;
    emit(NovelImportInitial());
  }

  @override
  Future<void> close() {
    _importStatusSubscription?.cancel();
    return super.close();
  }
}
