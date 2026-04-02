; ModuleID = 'runtime/runtime.ll'
source_filename = "runtime/runtime.ll"
target datalayout = "e-m:e-p270:32:32-p271:32:32-p272:64:64-i64:64-i128:128-f80:128-n8:16:32:64-S128"
target triple = "x86_64-pc-linux-gnu"

%struct.stat = type { i64, i64, i64, i32, i32, i32, i32, i64, i64, i64, i64, %struct.timespec, %struct.timespec, %struct.timespec, [3 x i64] }
%struct.timespec = type { i64, i64 }
%struct.DiSlot = type { i32, %union.anon }
%union.anon = type { %struct.DiIntVec }
%struct.DiIntVec = type { ptr, i64, i64 }

@g_argc = internal unnamed_addr global i32 0, align 4
@g_argv = internal unnamed_addr global ptr null, align 8
@.str = private unnamed_addr constant [1 x i8] zeroinitializer, align 1
@.str.1 = private unnamed_addr constant [3 x i8] c"rb\00", align 1
@.str.2 = private unnamed_addr constant [3 x i8] c"%d\00", align 1
@.str.3 = private unnamed_addr constant [4 x i8] c"%d\0A\00", align 1
@.str.6 = private unnamed_addr constant [6 x i8] c"0x%x\0A\00", align 1
@g_slot_count = internal unnamed_addr global i32 0, align 4
@g_slots = internal unnamed_addr global ptr null, align 8
@str = private unnamed_addr constant [7 x i8] c"(null)\00", align 1

; Function Attrs: mustprogress nofree norecurse nosync nounwind willreturn memory(write, argmem: none, inaccessiblemem: none) uwtable
define dso_local void @di_runtime_set_argv(i32 noundef %0, ptr noundef %1) local_unnamed_addr #0 {
  store i32 %0, ptr @g_argc, align 4, !tbaa !5
  store ptr %1, ptr @g_argv, align 8, !tbaa !9
  ret void
}

; Function Attrs: mustprogress nofree norecurse nosync nounwind willreturn memory(read, argmem: none, inaccessiblemem: none) uwtable
define dso_local i32 @di_runtime_argc() local_unnamed_addr #1 {
  %1 = load i32, ptr @g_argc, align 4, !tbaa !5
  ret i32 %1
}

; Function Attrs: mustprogress nofree norecurse nosync nounwind willreturn memory(read, inaccessiblemem: none) uwtable
define dso_local nonnull ptr @di_runtime_argv(i32 noundef %0) local_unnamed_addr #2 {
  %2 = load ptr, ptr @g_argv, align 8, !tbaa !9
  %3 = icmp ne ptr %2, null
  %4 = icmp sgt i32 %0, -1
  %5 = and i1 %4, %3
  %6 = load i32, ptr @g_argc, align 4
  %7 = icmp sgt i32 %6, %0
  %8 = select i1 %5, i1 %7, i1 false
  br i1 %8, label %9, label %15

9:                                                ; preds = %1
  %10 = zext i32 %0 to i64
  %11 = getelementptr inbounds ptr, ptr %2, i64 %10
  %12 = load ptr, ptr %11, align 8, !tbaa !9
  %13 = icmp eq ptr %12, null
  %14 = select i1 %13, ptr @.str, ptr %12
  br label %15

15:                                               ; preds = %1, %9
  %16 = phi ptr [ %14, %9 ], [ @.str, %1 ]
  ret ptr %16
}

; Function Attrs: nofree nounwind uwtable
define dso_local i32 @di_runtime_file_size(ptr noundef readonly %0) local_unnamed_addr #3 {
  %2 = alloca %struct.stat, align 8
  call void @llvm.lifetime.start.p0(i64 144, ptr nonnull %2) #22
  %3 = icmp eq ptr %0, null
  br i1 %3, label %18, label %4

4:                                                ; preds = %1
  %5 = call i32 @stat(ptr noundef nonnull %0, ptr noundef nonnull %2) #22
  %6 = icmp eq i32 %5, 0
  br i1 %6, label %7, label %18

7:                                                ; preds = %4
  %8 = getelementptr inbounds %struct.stat, ptr %2, i64 0, i32 3
  %9 = load i32, ptr %8, align 8, !tbaa !11
  %10 = and i32 %9, 61440
  %11 = icmp eq i32 %10, 32768
  br i1 %11, label %12, label %18

12:                                               ; preds = %7
  %13 = getelementptr inbounds %struct.stat, ptr %2, i64 0, i32 8
  %14 = load i64, ptr %13, align 8, !tbaa !15
  %15 = icmp sgt i64 %14, 2147483647
  %16 = trunc i64 %14 to i32
  %17 = select i1 %15, i32 -1, i32 %16
  br label %18

18:                                               ; preds = %12, %4, %7, %1
  %19 = phi i32 [ -1, %1 ], [ -1, %7 ], [ -1, %4 ], [ %17, %12 ]
  call void @llvm.lifetime.end.p0(i64 144, ptr nonnull %2) #22
  ret i32 %19
}

; Function Attrs: mustprogress nocallback nofree nosync nounwind willreturn memory(argmem: readwrite)
declare void @llvm.lifetime.start.p0(i64 immarg, ptr nocapture) #4

; Function Attrs: nofree nounwind
declare noundef i32 @stat(ptr nocapture noundef readonly, ptr nocapture noundef) local_unnamed_addr #5

; Function Attrs: mustprogress nocallback nofree nosync nounwind willreturn memory(argmem: readwrite)
declare void @llvm.lifetime.end.p0(i64 immarg, ptr nocapture) #4

; Function Attrs: nounwind uwtable
define dso_local noundef ptr @di_runtime_read_file(ptr noundef readonly %0) local_unnamed_addr #6 {
  %2 = icmp eq ptr %0, null
  br i1 %2, label %30, label %3

3:                                                ; preds = %1
  %4 = tail call noalias ptr @fopen(ptr noundef nonnull %0, ptr noundef nonnull @.str.1)
  %5 = icmp eq ptr %4, null
  br i1 %5, label %30, label %6

6:                                                ; preds = %3
  %7 = tail call i32 @fseek(ptr noundef nonnull %4, i64 noundef 0, i32 noundef 2)
  %8 = icmp eq i32 %7, 0
  br i1 %8, label %9, label %27

9:                                                ; preds = %6
  %10 = tail call i64 @ftell(ptr noundef nonnull %4)
  %11 = icmp slt i64 %10, 0
  br i1 %11, label %27, label %12

12:                                               ; preds = %9
  %13 = tail call i32 @fseek(ptr noundef nonnull %4, i64 noundef 0, i32 noundef 0)
  %14 = icmp eq i32 %13, 0
  br i1 %14, label %15, label %27

15:                                               ; preds = %12
  %16 = add nuw i64 %10, 1
  %17 = tail call noalias ptr @malloc(i64 noundef %16) #23
  %18 = icmp eq ptr %17, null
  br i1 %18, label %27, label %19

19:                                               ; preds = %15
  %20 = icmp eq i64 %10, 0
  br i1 %20, label %25, label %21

21:                                               ; preds = %19
  %22 = tail call i64 @fread(ptr noundef nonnull %17, i64 noundef 1, i64 noundef %10, ptr noundef nonnull %4)
  %23 = icmp eq i64 %22, %10
  br i1 %23, label %25, label %24

24:                                               ; preds = %21
  tail call void @free(ptr noundef %17) #22
  br label %27

25:                                               ; preds = %21, %19
  %26 = getelementptr inbounds i8, ptr %17, i64 %10
  store i8 0, ptr %26, align 1, !tbaa !16
  br label %27

27:                                               ; preds = %15, %12, %9, %6, %24, %25
  %28 = phi ptr [ %17, %25 ], [ @.str, %24 ], [ @.str, %6 ], [ @.str, %9 ], [ @.str, %12 ], [ @.str, %15 ]
  %29 = tail call i32 @fclose(ptr noundef nonnull %4)
  br label %30

30:                                               ; preds = %27, %3, %1
  %31 = phi ptr [ @.str, %1 ], [ @.str, %3 ], [ %28, %27 ]
  ret ptr %31
}

; Function Attrs: nofree nounwind
declare noalias noundef ptr @fopen(ptr nocapture noundef readonly, ptr nocapture noundef readonly) local_unnamed_addr #5

; Function Attrs: nofree nounwind
declare noundef i32 @fseek(ptr nocapture noundef, i64 noundef, i32 noundef) local_unnamed_addr #5

; Function Attrs: nofree nounwind
declare noundef i32 @fclose(ptr nocapture noundef) local_unnamed_addr #5

; Function Attrs: nofree nounwind
declare noundef i64 @ftell(ptr nocapture noundef) local_unnamed_addr #5

; Function Attrs: mustprogress nofree nounwind willreturn allockind("alloc,uninitialized") allocsize(0) memory(inaccessiblemem: readwrite)
declare noalias noundef ptr @malloc(i64 noundef) local_unnamed_addr #7

; Function Attrs: nofree nounwind
declare noundef i64 @fread(ptr nocapture noundef, i64 noundef, i64 noundef, ptr nocapture noundef) local_unnamed_addr #5

; Function Attrs: mustprogress nounwind willreturn allockind("free") memory(argmem: readwrite, inaccessiblemem: readwrite)
declare void @free(ptr allocptr nocapture noundef) local_unnamed_addr #8

; Function Attrs: nofree norecurse nosync nounwind memory(argmem: read) uwtable
define dso_local i32 @di_runtime_str_len(ptr noundef readonly %0) local_unnamed_addr #9 {
  %2 = icmp eq ptr %0, null
  br i1 %2, label %11, label %3

3:                                                ; preds = %1, %3
  %4 = phi i64 [ %8, %3 ], [ 0, %1 ]
  %5 = getelementptr inbounds i8, ptr %0, i64 %4
  %6 = load i8, ptr %5, align 1, !tbaa !16
  %7 = icmp eq i8 %6, 0
  %8 = add nuw i64 %4, 1
  br i1 %7, label %9, label %3, !llvm.loop !17

9:                                                ; preds = %3
  %10 = trunc i64 %4 to i32
  br label %11

11:                                               ; preds = %9, %1
  %12 = phi i32 [ 0, %1 ], [ %10, %9 ]
  ret i32 %12
}

; Function Attrs: nofree norecurse nosync nounwind memory(argmem: read) uwtable
define dso_local i32 @di_runtime_str_byte(ptr noundef readonly %0, i32 noundef %1) local_unnamed_addr #9 {
  %3 = icmp eq ptr %0, null
  %4 = icmp slt i32 %1, 0
  %5 = or i1 %3, %4
  br i1 %5, label %22, label %6

6:                                                ; preds = %2
  %7 = add i32 %1, 1
  %8 = zext i32 %7 to i64
  br label %12

9:                                                ; preds = %12
  %10 = add nuw nsw i64 %13, 1
  %11 = icmp eq i64 %10, %8
  br i1 %11, label %17, label %12, !llvm.loop !20

12:                                               ; preds = %6, %9
  %13 = phi i64 [ 0, %6 ], [ %10, %9 ]
  %14 = getelementptr inbounds i8, ptr %0, i64 %13
  %15 = load i8, ptr %14, align 1, !tbaa !16
  %16 = icmp eq i8 %15, 0
  br i1 %16, label %22, label %9

17:                                               ; preds = %9
  %18 = zext i32 %1 to i64
  %19 = getelementptr inbounds i8, ptr %0, i64 %18
  %20 = load i8, ptr %19, align 1, !tbaa !16
  %21 = zext i8 %20 to i32
  br label %22

22:                                               ; preds = %12, %2, %17
  %23 = phi i32 [ %21, %17 ], [ -1, %2 ], [ -1, %12 ]
  ret i32 %23
}

; Function Attrs: nofree nounwind uwtable
define dso_local noundef ptr @di_runtime_str_slice(ptr noundef readonly %0, i32 noundef %1, i32 noundef %2) local_unnamed_addr #3 {
  %4 = icmp eq ptr %0, null
  %5 = or i32 %2, %1
  %6 = icmp slt i32 %5, 0
  %7 = or i1 %4, %6
  br i1 %7, label %37, label %8

8:                                                ; preds = %3, %8
  %9 = phi i64 [ %13, %8 ], [ 0, %3 ]
  %10 = getelementptr inbounds i8, ptr %0, i64 %9
  %11 = load i8, ptr %10, align 1, !tbaa !16
  %12 = icmp eq i8 %11, 0
  %13 = add nuw i64 %9, 1
  br i1 %12, label %14, label %8, !llvm.loop !17

14:                                               ; preds = %8
  %15 = trunc i64 %9 to i32
  %16 = icmp slt i32 %15, %1
  br i1 %16, label %37, label %17

17:                                               ; preds = %14
  %18 = add nuw nsw i32 %2, %1
  %19 = icmp sgt i32 %18, %15
  %20 = sub nsw i32 %15, %1
  %21 = select i1 %19, i32 %20, i32 %2
  %22 = icmp slt i32 %21, 1
  br i1 %22, label %37, label %23

23:                                               ; preds = %17
  %24 = zext i32 %21 to i64
  %25 = add nuw nsw i64 %24, 1
  %26 = tail call noalias ptr @malloc(i64 noundef %25) #23
  %27 = icmp eq ptr %26, null
  br i1 %27, label %37, label %28

28:                                               ; preds = %23
  %29 = sext i32 %1 to i64
  %30 = getelementptr i8, ptr %0, i64 %29
  %31 = xor i32 %1, -1
  %32 = tail call i32 @llvm.smin.i32(i32 %15, i32 %18)
  %33 = add i32 %32, %31
  %34 = zext i32 %33 to i64
  %35 = add nuw nsw i64 %34, 1
  tail call void @llvm.memcpy.p0.p0.i64(ptr noundef nonnull align 1 dereferenceable(1) %26, ptr noundef nonnull align 1 dereferenceable(1) %30, i64 %35, i1 false), !tbaa !16
  %36 = getelementptr inbounds i8, ptr %26, i64 %24
  store i8 0, ptr %36, align 1, !tbaa !16
  br label %37

37:                                               ; preds = %23, %17, %14, %3, %28
  %38 = phi ptr [ %26, %28 ], [ @.str, %3 ], [ @.str, %14 ], [ @.str, %17 ], [ @.str, %23 ]
  ret ptr %38
}

; Function Attrs: mustprogress nofree nounwind willreturn memory(argmem: read) uwtable
define dso_local i32 @di_runtime_str_eq(ptr noundef readonly %0, ptr noundef readonly %1) local_unnamed_addr #10 {
  %3 = icmp eq ptr %0, null
  %4 = icmp eq ptr %1, null
  %5 = or i1 %3, %4
  br i1 %5, label %6, label %8

6:                                                ; preds = %2
  %7 = icmp eq ptr %0, %1
  br label %11

8:                                                ; preds = %2
  %9 = tail call i32 @strcmp(ptr noundef nonnull dereferenceable(1) %0, ptr noundef nonnull dereferenceable(1) %1) #24
  %10 = icmp eq i32 %9, 0
  br label %11

11:                                               ; preds = %8, %6
  %12 = phi i1 [ %7, %6 ], [ %10, %8 ]
  %13 = zext i1 %12 to i32
  ret i32 %13
}

; Function Attrs: mustprogress nofree nounwind willreturn memory(argmem: read)
declare i32 @strcmp(ptr nocapture noundef, ptr nocapture noundef) local_unnamed_addr #11

; Function Attrs: nofree nounwind uwtable
define dso_local noundef ptr @di_runtime_int_to_str(i32 noundef %0) local_unnamed_addr #3 {
  %2 = tail call noalias dereferenceable_or_null(32) ptr @malloc(i64 noundef 32) #23
  %3 = icmp eq ptr %2, null
  br i1 %3, label %6, label %4

4:                                                ; preds = %1
  %5 = tail call i32 (ptr, i64, ptr, ...) @snprintf(ptr noundef nonnull dereferenceable(1) %2, i64 noundef 32, ptr noundef nonnull @.str.2, i32 noundef %0) #22
  br label %6

6:                                                ; preds = %1, %4
  %7 = phi ptr [ %2, %4 ], [ @.str, %1 ]
  ret ptr %7
}

; Function Attrs: nofree nounwind
declare noundef i32 @snprintf(ptr noalias nocapture noundef writeonly, i64 noundef, ptr nocapture noundef readonly, ...) local_unnamed_addr #5

; Function Attrs: nounwind uwtable
define dso_local i32 @di_runtime_int_vec_new() local_unnamed_addr #6 {
  %1 = load i32, ptr @g_slot_count, align 4, !tbaa !5
  %2 = icmp sgt i32 %1, 0
  br i1 %2, label %3, label %17

3:                                                ; preds = %0
  %4 = load ptr, ptr @g_slots, align 8, !tbaa !9
  %5 = zext i32 %1 to i64
  br label %6

6:                                                ; preds = %14, %3
  %7 = phi i64 [ 0, %3 ], [ %15, %14 ]
  %8 = getelementptr inbounds %struct.DiSlot, ptr %4, i64 %7
  %9 = load i32, ptr %8, align 8, !tbaa !21
  %10 = icmp eq i32 %9, 0
  br i1 %10, label %11, label %14

11:                                               ; preds = %6
  %12 = trunc i64 %7 to i32
  tail call void @llvm.memset.p0.i64(ptr noundef nonnull align 8 dereferenceable(32) %8, i8 0, i64 32, i1 false)
  store i32 1, ptr %8, align 8, !tbaa !21
  %13 = add nuw nsw i32 %12, 1
  br label %27

14:                                               ; preds = %6
  %15 = add nuw nsw i64 %7, 1
  %16 = icmp eq i64 %15, %5
  br i1 %16, label %17, label %6, !llvm.loop !23

17:                                               ; preds = %14, %0
  %18 = load ptr, ptr @g_slots, align 8, !tbaa !9
  %19 = add nsw i32 %1, 1
  %20 = sext i32 %19 to i64
  %21 = shl nsw i64 %20, 5
  %22 = tail call ptr @realloc(ptr noundef %18, i64 noundef %21) #25
  %23 = icmp eq ptr %22, null
  br i1 %23, label %27, label %24

24:                                               ; preds = %17
  store ptr %22, ptr @g_slots, align 8, !tbaa !9
  %25 = sext i32 %1 to i64
  %26 = getelementptr inbounds %struct.DiSlot, ptr %22, i64 %25
  tail call void @llvm.memset.p0.i64(ptr noundef nonnull align 8 dereferenceable(32) %26, i8 0, i64 32, i1 false)
  store i32 1, ptr %26, align 8, !tbaa !21
  store i32 %19, ptr @g_slot_count, align 4, !tbaa !5
  br label %27

27:                                               ; preds = %11, %17, %24
  %28 = phi i32 [ %13, %11 ], [ %19, %24 ], [ 0, %17 ]
  ret i32 %28
}

; Function Attrs: mustprogress nofree norecurse nosync nounwind willreturn memory(read, inaccessiblemem: none) uwtable
define dso_local i32 @di_runtime_int_vec_len(i32 noundef %0) local_unnamed_addr #2 {
  %2 = icmp slt i32 %0, 1
  %3 = load i32, ptr @g_slot_count, align 4
  %4 = icmp slt i32 %3, %0
  %5 = select i1 %2, i1 true, i1 %4
  %6 = load ptr, ptr @g_slots, align 8
  %7 = zext i32 %0 to i64
  %8 = getelementptr %struct.DiSlot, ptr %6, i64 %7
  %9 = getelementptr %struct.DiSlot, ptr %8, i64 -1
  %10 = icmp eq ptr %9, null
  %11 = select i1 %5, i1 true, i1 %10
  br i1 %11, label %16, label %12

12:                                               ; preds = %1
  %13 = load i32, ptr %9, align 8, !tbaa !21
  %14 = icmp eq i32 %13, 1
  %15 = select i1 %14, ptr %9, ptr null
  br label %16

16:                                               ; preds = %1, %12
  %17 = phi ptr [ null, %1 ], [ %15, %12 ]
  %18 = icmp eq ptr %17, null
  br i1 %18, label %25, label %19

19:                                               ; preds = %16
  %20 = getelementptr inbounds %struct.DiSlot, ptr %17, i64 0, i32 1, i32 0, i32 1
  %21 = load i64, ptr %20, align 8, !tbaa !16
  %22 = icmp ugt i64 %21, 2147483647
  %23 = trunc i64 %21 to i32
  %24 = select i1 %22, i32 -1, i32 %23
  br label %25

25:                                               ; preds = %19, %16
  %26 = phi i32 [ -1, %16 ], [ %24, %19 ]
  ret i32 %26
}

; Function Attrs: mustprogress nofree norecurse nosync nounwind willreturn memory(read, inaccessiblemem: none) uwtable
define dso_local i32 @di_runtime_int_vec_get(i32 noundef %0, i32 noundef %1) local_unnamed_addr #2 {
  %3 = icmp slt i32 %0, 1
  %4 = load i32, ptr @g_slot_count, align 4
  %5 = icmp slt i32 %4, %0
  %6 = select i1 %3, i1 true, i1 %5
  %7 = load ptr, ptr @g_slots, align 8
  %8 = zext i32 %0 to i64
  %9 = getelementptr %struct.DiSlot, ptr %7, i64 %8
  %10 = getelementptr %struct.DiSlot, ptr %9, i64 -1
  %11 = icmp eq ptr %10, null
  %12 = select i1 %6, i1 true, i1 %11
  br i1 %12, label %17, label %13

13:                                               ; preds = %2
  %14 = load i32, ptr %10, align 8, !tbaa !21
  %15 = icmp eq i32 %14, 1
  %16 = select i1 %15, ptr %10, ptr null
  br label %17

17:                                               ; preds = %2, %13
  %18 = phi ptr [ null, %2 ], [ %16, %13 ]
  %19 = icmp eq ptr %18, null
  %20 = icmp slt i32 %1, 0
  %21 = or i1 %20, %19
  br i1 %21, label %32, label %22

22:                                               ; preds = %17
  %23 = zext i32 %1 to i64
  %24 = getelementptr inbounds %struct.DiSlot, ptr %18, i64 0, i32 1, i32 0, i32 1
  %25 = load i64, ptr %24, align 8, !tbaa !16
  %26 = icmp ugt i64 %25, %23
  br i1 %26, label %27, label %32

27:                                               ; preds = %22
  %28 = getelementptr inbounds %struct.DiSlot, ptr %18, i64 0, i32 1
  %29 = load ptr, ptr %28, align 8, !tbaa !16
  %30 = getelementptr inbounds i32, ptr %29, i64 %23
  %31 = load i32, ptr %30, align 4, !tbaa !5
  br label %32

32:                                               ; preds = %22, %17, %27
  %33 = phi i32 [ %31, %27 ], [ -1, %17 ], [ -1, %22 ]
  ret i32 %33
}

; Function Attrs: mustprogress nounwind willreturn uwtable
define dso_local i32 @di_runtime_int_vec_push(i32 noundef %0, i32 noundef %1) local_unnamed_addr #12 {
  %3 = icmp slt i32 %0, 1
  %4 = load i32, ptr @g_slot_count, align 4
  %5 = icmp slt i32 %4, %0
  %6 = select i1 %3, i1 true, i1 %5
  %7 = load ptr, ptr @g_slots, align 8
  %8 = zext i32 %0 to i64
  %9 = getelementptr %struct.DiSlot, ptr %7, i64 %8
  %10 = getelementptr %struct.DiSlot, ptr %9, i64 -1
  %11 = icmp eq ptr %10, null
  %12 = select i1 %6, i1 true, i1 %11
  br i1 %12, label %17, label %13

13:                                               ; preds = %2
  %14 = load i32, ptr %10, align 8, !tbaa !21
  %15 = icmp eq i32 %14, 1
  %16 = select i1 %15, ptr %10, ptr null
  br label %17

17:                                               ; preds = %2, %13
  %18 = phi ptr [ null, %2 ], [ %16, %13 ]
  %19 = icmp eq ptr %18, null
  br i1 %19, label %44, label %20

20:                                               ; preds = %17
  %21 = getelementptr inbounds %struct.DiSlot, ptr %18, i64 0, i32 1
  %22 = getelementptr inbounds %struct.DiSlot, ptr %18, i64 0, i32 1, i32 0, i32 1
  %23 = load i64, ptr %22, align 8, !tbaa !24
  %24 = getelementptr inbounds %struct.DiSlot, ptr %18, i64 0, i32 1, i32 0, i32 2
  %25 = load i64, ptr %24, align 8, !tbaa !26
  %26 = icmp ult i64 %23, %25
  br i1 %26, label %36, label %27

27:                                               ; preds = %20
  %28 = icmp eq i64 %25, 0
  %29 = shl i64 %25, 1
  %30 = select i1 %28, i64 8, i64 %29
  %31 = load ptr, ptr %21, align 8, !tbaa !27
  %32 = shl i64 %30, 2
  %33 = tail call ptr @realloc(ptr noundef %31, i64 noundef %32) #25
  %34 = icmp eq ptr %33, null
  br i1 %34, label %44, label %35

35:                                               ; preds = %27
  store ptr %33, ptr %21, align 8, !tbaa !27
  store i64 %30, ptr %24, align 8, !tbaa !26
  br label %36

36:                                               ; preds = %35, %20
  %37 = load ptr, ptr %21, align 8, !tbaa !27
  %38 = load i64, ptr %22, align 8, !tbaa !24
  %39 = getelementptr inbounds i32, ptr %37, i64 %38
  store i32 %1, ptr %39, align 4, !tbaa !5
  %40 = add i64 %38, 1
  store i64 %40, ptr %22, align 8, !tbaa !24
  %41 = icmp ugt i64 %40, 2147483647
  %42 = trunc i64 %40 to i32
  %43 = select i1 %41, i32 -1, i32 %42
  br label %44

44:                                               ; preds = %36, %27, %17
  %45 = phi i32 [ -1, %17 ], [ -1, %27 ], [ %43, %36 ]
  ret i32 %45
}

; Function Attrs: mustprogress nounwind willreturn allockind("realloc") allocsize(1) memory(argmem: readwrite, inaccessiblemem: readwrite)
declare noalias noundef ptr @realloc(ptr allocptr nocapture noundef, i64 noundef) local_unnamed_addr #13

; Function Attrs: mustprogress nounwind willreturn uwtable
define dso_local void @di_runtime_int_vec_free(i32 noundef %0) local_unnamed_addr #12 {
  %2 = icmp slt i32 %0, 1
  %3 = load i32, ptr @g_slot_count, align 4
  %4 = icmp slt i32 %3, %0
  %5 = select i1 %2, i1 true, i1 %4
  %6 = load ptr, ptr @g_slots, align 8
  %7 = zext i32 %0 to i64
  %8 = getelementptr %struct.DiSlot, ptr %6, i64 %7
  %9 = getelementptr %struct.DiSlot, ptr %8, i64 -1
  %10 = icmp eq ptr %9, null
  %11 = select i1 %5, i1 true, i1 %10
  br i1 %11, label %20, label %12

12:                                               ; preds = %1
  %13 = load i32, ptr %9, align 8, !tbaa !21
  %14 = add i32 %13, -1
  %15 = icmp ult i32 %14, 2
  br i1 %15, label %16, label %19

16:                                               ; preds = %12
  %17 = getelementptr %struct.DiSlot, ptr %8, i64 -1, i32 1
  %18 = load ptr, ptr %17, align 8, !tbaa !16
  tail call void @free(ptr noundef %18) #22
  br label %19

19:                                               ; preds = %12, %16
  tail call void @llvm.memset.p0.i64(ptr noundef nonnull align 8 dereferenceable(32) %9, i8 0, i64 32, i1 false)
  br label %20

20:                                               ; preds = %1, %19
  ret void
}

; Function Attrs: nounwind uwtable
define dso_local i32 @di_runtime_str_builder_new() local_unnamed_addr #6 {
  %1 = load i32, ptr @g_slot_count, align 4, !tbaa !5
  %2 = icmp sgt i32 %1, 0
  br i1 %2, label %3, label %17

3:                                                ; preds = %0
  %4 = load ptr, ptr @g_slots, align 8, !tbaa !9
  %5 = zext i32 %1 to i64
  br label %6

6:                                                ; preds = %14, %3
  %7 = phi i64 [ 0, %3 ], [ %15, %14 ]
  %8 = getelementptr inbounds %struct.DiSlot, ptr %4, i64 %7
  %9 = load i32, ptr %8, align 8, !tbaa !21
  %10 = icmp eq i32 %9, 0
  br i1 %10, label %11, label %14

11:                                               ; preds = %6
  %12 = trunc i64 %7 to i32
  tail call void @llvm.memset.p0.i64(ptr noundef nonnull align 8 dereferenceable(32) %8, i8 0, i64 32, i1 false)
  store i32 2, ptr %8, align 8, !tbaa !21
  %13 = add nuw nsw i32 %12, 1
  br label %27

14:                                               ; preds = %6
  %15 = add nuw nsw i64 %7, 1
  %16 = icmp eq i64 %15, %5
  br i1 %16, label %17, label %6, !llvm.loop !23

17:                                               ; preds = %14, %0
  %18 = load ptr, ptr @g_slots, align 8, !tbaa !9
  %19 = add nsw i32 %1, 1
  %20 = sext i32 %19 to i64
  %21 = shl nsw i64 %20, 5
  %22 = tail call ptr @realloc(ptr noundef %18, i64 noundef %21) #25
  %23 = icmp eq ptr %22, null
  br i1 %23, label %27, label %24

24:                                               ; preds = %17
  store ptr %22, ptr @g_slots, align 8, !tbaa !9
  %25 = sext i32 %1 to i64
  %26 = getelementptr inbounds %struct.DiSlot, ptr %22, i64 %25
  tail call void @llvm.memset.p0.i64(ptr noundef nonnull align 8 dereferenceable(32) %26, i8 0, i64 32, i1 false)
  store i32 2, ptr %26, align 8, !tbaa !21
  store i32 %19, ptr @g_slot_count, align 4, !tbaa !5
  br label %27

27:                                               ; preds = %11, %17, %24
  %28 = phi i32 [ %13, %11 ], [ %19, %24 ], [ 0, %17 ]
  ret i32 %28
}

; Function Attrs: nounwind uwtable
define dso_local void @di_runtime_str_builder_append(i32 noundef %0, ptr noundef readonly %1) local_unnamed_addr #6 {
  %3 = icmp slt i32 %0, 1
  %4 = load i32, ptr @g_slot_count, align 4
  %5 = icmp slt i32 %4, %0
  %6 = select i1 %3, i1 true, i1 %5
  %7 = load ptr, ptr @g_slots, align 8
  %8 = zext i32 %0 to i64
  %9 = getelementptr %struct.DiSlot, ptr %7, i64 %8
  %10 = getelementptr %struct.DiSlot, ptr %9, i64 -1
  %11 = icmp eq ptr %10, null
  %12 = select i1 %6, i1 true, i1 %11
  br i1 %12, label %17, label %13

13:                                               ; preds = %2
  %14 = load i32, ptr %10, align 8, !tbaa !21
  %15 = icmp eq i32 %14, 2
  %16 = select i1 %15, ptr %10, ptr null
  br label %17

17:                                               ; preds = %2, %13
  %18 = phi ptr [ null, %2 ], [ %16, %13 ]
  %19 = icmp eq ptr %18, null
  %20 = icmp eq ptr %1, null
  %21 = or i1 %20, %19
  br i1 %21, label %52, label %22

22:                                               ; preds = %17
  %23 = getelementptr inbounds %struct.DiSlot, ptr %18, i64 0, i32 1
  %24 = tail call i64 @strlen(ptr noundef nonnull dereferenceable(1) %1) #24
  %25 = getelementptr inbounds %struct.DiSlot, ptr %18, i64 0, i32 1, i32 0, i32 1
  %26 = load i64, ptr %25, align 8, !tbaa !24
  %27 = add i64 %24, 1
  %28 = add i64 %27, %26
  %29 = getelementptr inbounds %struct.DiSlot, ptr %18, i64 0, i32 1, i32 0, i32 2
  %30 = load i64, ptr %29, align 8, !tbaa !26
  %31 = icmp ugt i64 %28, %30
  br i1 %31, label %32, label %44

32:                                               ; preds = %22
  %33 = icmp eq i64 %30, 0
  %34 = select i1 %33, i64 64, i64 %30
  br label %35

35:                                               ; preds = %35, %32
  %36 = phi i64 [ %34, %32 ], [ %38, %35 ]
  %37 = icmp ult i64 %36, %28
  %38 = shl i64 %36, 1
  br i1 %37, label %35, label %39, !llvm.loop !28

39:                                               ; preds = %35
  %40 = load ptr, ptr %23, align 8, !tbaa !27
  %41 = tail call ptr @realloc(ptr noundef %40, i64 noundef %36) #25
  %42 = icmp eq ptr %41, null
  br i1 %42, label %52, label %43

43:                                               ; preds = %39
  store ptr %41, ptr %23, align 8, !tbaa !27
  store i64 %36, ptr %29, align 8, !tbaa !26
  br label %44

44:                                               ; preds = %43, %22
  %45 = load ptr, ptr %23, align 8, !tbaa !27
  %46 = load i64, ptr %25, align 8, !tbaa !24
  %47 = getelementptr inbounds i8, ptr %45, i64 %46
  tail call void @llvm.memcpy.p0.p0.i64(ptr align 1 %47, ptr align 1 %1, i64 %24, i1 false)
  %48 = load i64, ptr %25, align 8, !tbaa !24
  %49 = add i64 %48, %24
  store i64 %49, ptr %25, align 8, !tbaa !24
  %50 = load ptr, ptr %23, align 8, !tbaa !27
  %51 = getelementptr inbounds i8, ptr %50, i64 %49
  store i8 0, ptr %51, align 1, !tbaa !16
  br label %52

52:                                               ; preds = %39, %17, %44
  ret void
}

; Function Attrs: mustprogress nofree nounwind willreturn memory(argmem: read)
declare i64 @strlen(ptr nocapture noundef) local_unnamed_addr #11

; Function Attrs: mustprogress nocallback nofree nounwind willreturn memory(argmem: readwrite)
declare void @llvm.memcpy.p0.p0.i64(ptr noalias nocapture writeonly, ptr noalias nocapture readonly, i64, i1 immarg) #14

; Function Attrs: mustprogress nofree norecurse nosync nounwind willreturn memory(read, inaccessiblemem: none) uwtable
define dso_local i32 @di_runtime_str_builder_len(i32 noundef %0) local_unnamed_addr #2 {
  %2 = icmp slt i32 %0, 1
  %3 = load i32, ptr @g_slot_count, align 4
  %4 = icmp slt i32 %3, %0
  %5 = select i1 %2, i1 true, i1 %4
  %6 = load ptr, ptr @g_slots, align 8
  %7 = zext i32 %0 to i64
  %8 = getelementptr %struct.DiSlot, ptr %6, i64 %7
  %9 = getelementptr %struct.DiSlot, ptr %8, i64 -1
  %10 = icmp eq ptr %9, null
  %11 = select i1 %5, i1 true, i1 %10
  br i1 %11, label %16, label %12

12:                                               ; preds = %1
  %13 = load i32, ptr %9, align 8, !tbaa !21
  %14 = icmp eq i32 %13, 2
  %15 = select i1 %14, ptr %9, ptr null
  br label %16

16:                                               ; preds = %1, %12
  %17 = phi ptr [ null, %1 ], [ %15, %12 ]
  %18 = icmp eq ptr %17, null
  br i1 %18, label %25, label %19

19:                                               ; preds = %16
  %20 = getelementptr inbounds %struct.DiSlot, ptr %17, i64 0, i32 1, i32 0, i32 1
  %21 = load i64, ptr %20, align 8, !tbaa !16
  %22 = icmp ugt i64 %21, 2147483647
  %23 = trunc i64 %21 to i32
  %24 = select i1 %22, i32 -1, i32 %23
  br label %25

25:                                               ; preds = %19, %16
  %26 = phi i32 [ -1, %16 ], [ %24, %19 ]
  ret i32 %26
}

; Function Attrs: mustprogress nofree nounwind willreturn uwtable
define dso_local noundef ptr @di_runtime_str_builder_to_str(i32 noundef %0) local_unnamed_addr #15 {
  %2 = icmp slt i32 %0, 1
  %3 = load i32, ptr @g_slot_count, align 4
  %4 = icmp slt i32 %3, %0
  %5 = select i1 %2, i1 true, i1 %4
  %6 = load ptr, ptr @g_slots, align 8
  %7 = zext i32 %0 to i64
  %8 = getelementptr %struct.DiSlot, ptr %6, i64 %7
  %9 = getelementptr %struct.DiSlot, ptr %8, i64 -1
  %10 = icmp eq ptr %9, null
  %11 = select i1 %5, i1 true, i1 %10
  br i1 %11, label %16, label %12

12:                                               ; preds = %1
  %13 = load i32, ptr %9, align 8, !tbaa !21
  %14 = icmp eq i32 %13, 2
  %15 = select i1 %14, ptr %9, ptr null
  br label %16

16:                                               ; preds = %1, %12
  %17 = phi ptr [ null, %1 ], [ %15, %12 ]
  %18 = icmp eq ptr %17, null
  br i1 %18, label %35, label %19

19:                                               ; preds = %16
  %20 = getelementptr inbounds %struct.DiSlot, ptr %17, i64 0, i32 1
  %21 = getelementptr inbounds %struct.DiSlot, ptr %17, i64 0, i32 1, i32 0, i32 1
  %22 = load i64, ptr %21, align 8, !tbaa !24
  %23 = add i64 %22, 1
  %24 = tail call noalias ptr @malloc(i64 noundef %23) #23
  %25 = icmp eq ptr %24, null
  br i1 %25, label %35, label %26

26:                                               ; preds = %19
  %27 = icmp eq i64 %22, 0
  br i1 %27, label %32, label %28

28:                                               ; preds = %26
  %29 = load ptr, ptr %20, align 8, !tbaa !27
  %30 = icmp eq ptr %29, null
  br i1 %30, label %32, label %31

31:                                               ; preds = %28
  tail call void @llvm.memcpy.p0.p0.i64(ptr nonnull align 1 %24, ptr nonnull align 1 %29, i64 %22, i1 false)
  br label %32

32:                                               ; preds = %31, %28, %26
  %33 = load i64, ptr %21, align 8, !tbaa !24
  %34 = getelementptr inbounds i8, ptr %24, i64 %33
  store i8 0, ptr %34, align 1, !tbaa !16
  br label %35

35:                                               ; preds = %19, %16, %32
  %36 = phi ptr [ %24, %32 ], [ @.str, %16 ], [ @.str, %19 ]
  ret ptr %36
}

; Function Attrs: mustprogress nounwind willreturn uwtable
define dso_local void @di_runtime_str_builder_free(i32 noundef %0) local_unnamed_addr #12 {
  %2 = icmp slt i32 %0, 1
  %3 = load i32, ptr @g_slot_count, align 4
  %4 = icmp slt i32 %3, %0
  %5 = select i1 %2, i1 true, i1 %4
  %6 = load ptr, ptr @g_slots, align 8
  %7 = zext i32 %0 to i64
  %8 = getelementptr %struct.DiSlot, ptr %6, i64 %7
  %9 = getelementptr %struct.DiSlot, ptr %8, i64 -1
  %10 = icmp eq ptr %9, null
  %11 = select i1 %5, i1 true, i1 %10
  br i1 %11, label %20, label %12

12:                                               ; preds = %1
  %13 = load i32, ptr %9, align 8, !tbaa !21
  %14 = add i32 %13, -1
  %15 = icmp ult i32 %14, 2
  br i1 %15, label %16, label %19

16:                                               ; preds = %12
  %17 = getelementptr %struct.DiSlot, ptr %8, i64 -1, i32 1
  %18 = load ptr, ptr %17, align 8, !tbaa !16
  tail call void @free(ptr noundef %18) #22
  br label %19

19:                                               ; preds = %12, %16
  tail call void @llvm.memset.p0.i64(ptr noundef nonnull align 8 dereferenceable(32) %9, i8 0, i64 32, i1 false)
  br label %20

20:                                               ; preds = %1, %19
  ret void
}

; Function Attrs: nofree nounwind uwtable
define dso_local void @di_runtime_print_int(i32 noundef %0) local_unnamed_addr #3 {
  %2 = tail call i32 (ptr, ...) @printf(ptr noundef nonnull dereferenceable(1) @.str.3, i32 noundef %0)
  ret void
}

; Function Attrs: nofree nounwind
declare noundef i32 @printf(ptr nocapture noundef readonly, ...) local_unnamed_addr #5

; Function Attrs: nofree nounwind uwtable
define dso_local void @di_runtime_print_str(ptr noundef readonly %0) local_unnamed_addr #3 {
  %2 = icmp eq ptr %0, null
  %3 = select i1 %2, ptr @str, ptr %0
  %4 = tail call i32 @puts(ptr nonnull dereferenceable(1) %3)
  ret void
}

; Function Attrs: nofree nounwind uwtable
define dso_local void @di_runtime_print_hex(i32 noundef %0) local_unnamed_addr #3 {
  %2 = tail call i32 (ptr, ...) @printf(ptr noundef nonnull dereferenceable(1) @.str.6, i32 noundef %0)
  ret void
}

; Function Attrs: nofree nounwind uwtable
define dso_local noundef i32 @di_runtime_write(i32 noundef %0, ptr noundef readonly %1) local_unnamed_addr #3 {
  %3 = icmp eq ptr %1, null
  br i1 %3, label %13, label %4

4:                                                ; preds = %2, %4
  %5 = phi i64 [ %9, %4 ], [ 0, %2 ]
  %6 = getelementptr inbounds i8, ptr %1, i64 %5
  %7 = load i8, ptr %6, align 1, !tbaa !16
  %8 = icmp eq i8 %7, 0
  %9 = add i64 %5, 1
  br i1 %8, label %10, label %4, !llvm.loop !29

10:                                               ; preds = %4
  %11 = tail call i64 @write(i32 noundef %0, ptr noundef nonnull %1, i64 noundef %5) #22
  %12 = trunc i64 %11 to i32
  br label %13

13:                                               ; preds = %2, %10
  %14 = phi i32 [ %12, %10 ], [ -1, %2 ]
  ret i32 %14
}

; Function Attrs: nofree
declare noundef i64 @write(i32 noundef, ptr nocapture noundef readonly, i64 noundef) local_unnamed_addr #16

; Function Attrs: noreturn nounwind uwtable
define dso_local void @di_runtime_exit(i32 noundef %0) local_unnamed_addr #17 {
  tail call void @exit(i32 noundef %0) #26
  unreachable
}

; Function Attrs: noreturn nounwind
declare void @exit(i32 noundef) local_unnamed_addr #18

; Function Attrs: noreturn nounwind uwtable
define dso_local void @di_runtime_abort() local_unnamed_addr #17 {
  tail call void @abort() #26
  unreachable
}

; Function Attrs: noreturn nounwind
declare void @abort() local_unnamed_addr #18

; Bootstrap / self-host: getenv and system (libc) for Di-hosted compiler driver.
declare noalias ptr @getenv(ptr nocapture noundef readonly) local_unnamed_addr #5
declare i32 @system(ptr nocapture noundef readonly) local_unnamed_addr #5

define dso_local ptr @di_runtime_getenv(ptr noundef %0) local_unnamed_addr #6 {
  %2 = tail call ptr @getenv(ptr noundef nonnull %0)
  %3 = icmp eq ptr %2, null
  br i1 %3, label %getenv_empty, label %getenv_ok

getenv_empty:
  ret ptr @.str

getenv_ok:
  ret ptr %2
}

define dso_local i32 @di_runtime_system(ptr noundef %0) local_unnamed_addr #6 {
  %2 = tail call i32 @system(ptr noundef %0)
  ret i32 %2
}

; Function Attrs: mustprogress nocallback nofree nounwind willreturn memory(argmem: write)
declare void @llvm.memset.p0.i64(ptr nocapture writeonly, i8, i64, i1 immarg) #19

; Function Attrs: nofree nounwind
declare noundef i32 @puts(ptr nocapture noundef readonly) local_unnamed_addr #20

; Function Attrs: nocallback nofree nosync nounwind speculatable willreturn memory(none)
declare i32 @llvm.smin.i32(i32, i32) #21

attributes #0 = { mustprogress nofree norecurse nosync nounwind willreturn memory(write, argmem: none, inaccessiblemem: none) uwtable "min-legal-vector-width"="0" "no-trapping-math"="true" "stack-protector-buffer-size"="8" "target-cpu"="x86-64" "target-features"="+cmov,+cx8,+fxsr,+mmx,+sse,+sse2,+x87" "tune-cpu"="generic" }
attributes #1 = { mustprogress nofree norecurse nosync nounwind willreturn memory(read, argmem: none, inaccessiblemem: none) uwtable "min-legal-vector-width"="0" "no-trapping-math"="true" "stack-protector-buffer-size"="8" "target-cpu"="x86-64" "target-features"="+cmov,+cx8,+fxsr,+mmx,+sse,+sse2,+x87" "tune-cpu"="generic" }
attributes #2 = { mustprogress nofree norecurse nosync nounwind willreturn memory(read, inaccessiblemem: none) uwtable "min-legal-vector-width"="0" "no-trapping-math"="true" "stack-protector-buffer-size"="8" "target-cpu"="x86-64" "target-features"="+cmov,+cx8,+fxsr,+mmx,+sse,+sse2,+x87" "tune-cpu"="generic" }
attributes #3 = { nofree nounwind uwtable "min-legal-vector-width"="0" "no-trapping-math"="true" "stack-protector-buffer-size"="8" "target-cpu"="x86-64" "target-features"="+cmov,+cx8,+fxsr,+mmx,+sse,+sse2,+x87" "tune-cpu"="generic" }
attributes #4 = { mustprogress nocallback nofree nosync nounwind willreturn memory(argmem: readwrite) }
attributes #5 = { nofree nounwind "no-trapping-math"="true" "stack-protector-buffer-size"="8" "target-cpu"="x86-64" "target-features"="+cmov,+cx8,+fxsr,+mmx,+sse,+sse2,+x87" "tune-cpu"="generic" }
attributes #6 = { nounwind uwtable "min-legal-vector-width"="0" "no-trapping-math"="true" "stack-protector-buffer-size"="8" "target-cpu"="x86-64" "target-features"="+cmov,+cx8,+fxsr,+mmx,+sse,+sse2,+x87" "tune-cpu"="generic" }
attributes #7 = { mustprogress nofree nounwind willreturn allockind("alloc,uninitialized") allocsize(0) memory(inaccessiblemem: readwrite) "alloc-family"="malloc" "no-trapping-math"="true" "stack-protector-buffer-size"="8" "target-cpu"="x86-64" "target-features"="+cmov,+cx8,+fxsr,+mmx,+sse,+sse2,+x87" "tune-cpu"="generic" }
attributes #8 = { mustprogress nounwind willreturn allockind("free") memory(argmem: readwrite, inaccessiblemem: readwrite) "alloc-family"="malloc" "no-trapping-math"="true" "stack-protector-buffer-size"="8" "target-cpu"="x86-64" "target-features"="+cmov,+cx8,+fxsr,+mmx,+sse,+sse2,+x87" "tune-cpu"="generic" }
attributes #9 = { nofree norecurse nosync nounwind memory(argmem: read) uwtable "min-legal-vector-width"="0" "no-trapping-math"="true" "stack-protector-buffer-size"="8" "target-cpu"="x86-64" "target-features"="+cmov,+cx8,+fxsr,+mmx,+sse,+sse2,+x87" "tune-cpu"="generic" }
attributes #10 = { mustprogress nofree nounwind willreturn memory(argmem: read) uwtable "min-legal-vector-width"="0" "no-trapping-math"="true" "stack-protector-buffer-size"="8" "target-cpu"="x86-64" "target-features"="+cmov,+cx8,+fxsr,+mmx,+sse,+sse2,+x87" "tune-cpu"="generic" }
attributes #11 = { mustprogress nofree nounwind willreturn memory(argmem: read) "no-trapping-math"="true" "stack-protector-buffer-size"="8" "target-cpu"="x86-64" "target-features"="+cmov,+cx8,+fxsr,+mmx,+sse,+sse2,+x87" "tune-cpu"="generic" }
attributes #12 = { mustprogress nounwind willreturn uwtable "min-legal-vector-width"="0" "no-trapping-math"="true" "stack-protector-buffer-size"="8" "target-cpu"="x86-64" "target-features"="+cmov,+cx8,+fxsr,+mmx,+sse,+sse2,+x87" "tune-cpu"="generic" }
attributes #13 = { mustprogress nounwind willreturn allockind("realloc") allocsize(1) memory(argmem: readwrite, inaccessiblemem: readwrite) "alloc-family"="malloc" "no-trapping-math"="true" "stack-protector-buffer-size"="8" "target-cpu"="x86-64" "target-features"="+cmov,+cx8,+fxsr,+mmx,+sse,+sse2,+x87" "tune-cpu"="generic" }
attributes #14 = { mustprogress nocallback nofree nounwind willreturn memory(argmem: readwrite) }
attributes #15 = { mustprogress nofree nounwind willreturn uwtable "min-legal-vector-width"="0" "no-trapping-math"="true" "stack-protector-buffer-size"="8" "target-cpu"="x86-64" "target-features"="+cmov,+cx8,+fxsr,+mmx,+sse,+sse2,+x87" "tune-cpu"="generic" }
attributes #16 = { nofree "no-trapping-math"="true" "stack-protector-buffer-size"="8" "target-cpu"="x86-64" "target-features"="+cmov,+cx8,+fxsr,+mmx,+sse,+sse2,+x87" "tune-cpu"="generic" }
attributes #17 = { noreturn nounwind uwtable "min-legal-vector-width"="0" "no-trapping-math"="true" "stack-protector-buffer-size"="8" "target-cpu"="x86-64" "target-features"="+cmov,+cx8,+fxsr,+mmx,+sse,+sse2,+x87" "tune-cpu"="generic" }
attributes #18 = { noreturn nounwind "no-trapping-math"="true" "stack-protector-buffer-size"="8" "target-cpu"="x86-64" "target-features"="+cmov,+cx8,+fxsr,+mmx,+sse,+sse2,+x87" "tune-cpu"="generic" }
attributes #19 = { mustprogress nocallback nofree nounwind willreturn memory(argmem: write) }
attributes #20 = { nofree nounwind }
attributes #21 = { nocallback nofree nosync nounwind speculatable willreturn memory(none) }
attributes #22 = { nounwind }
attributes #23 = { nounwind allocsize(0) }
attributes #24 = { nounwind willreturn memory(read) }
attributes #25 = { nounwind allocsize(1) }
attributes #26 = { noreturn nounwind }

!llvm.module.flags = !{!0, !1, !2, !3}
!llvm.ident = !{!4}

!0 = !{i32 1, !"wchar_size", i32 4}
!1 = !{i32 8, !"PIC Level", i32 2}
!2 = !{i32 7, !"PIE Level", i32 2}
!3 = !{i32 7, !"uwtable", i32 2}
!4 = !{!"Debian clang version 18.1.8 (++20240731024826+3b5b5c1ec4a3-1~exp1~20240731144843.145)"}
!5 = !{!6, !6, i64 0}
!6 = !{!"int", !7, i64 0}
!7 = !{!"omnipotent char", !8, i64 0}
!8 = !{!"Simple C/C++ TBAA"}
!9 = !{!10, !10, i64 0}
!10 = !{!"any pointer", !7, i64 0}
!11 = !{!12, !6, i64 24}
!12 = !{!"stat", !13, i64 0, !13, i64 8, !13, i64 16, !6, i64 24, !6, i64 28, !6, i64 32, !6, i64 36, !13, i64 40, !13, i64 48, !13, i64 56, !13, i64 64, !14, i64 72, !14, i64 88, !14, i64 104, !7, i64 120}
!13 = !{!"long", !7, i64 0}
!14 = !{!"timespec", !13, i64 0, !13, i64 8}
!15 = !{!12, !13, i64 48}
!16 = !{!7, !7, i64 0}
!17 = distinct !{!17, !18, !19}
!18 = !{!"llvm.loop.mustprogress"}
!19 = !{!"llvm.loop.unroll.disable"}
!20 = distinct !{!20, !18, !19}
!21 = !{!22, !6, i64 0}
!22 = !{!"", !6, i64 0, !7, i64 8}
!23 = distinct !{!23, !18, !19}
!24 = !{!25, !13, i64 8}
!25 = !{!"", !10, i64 0, !13, i64 8, !13, i64 16}
!26 = !{!25, !13, i64 16}
!27 = !{!25, !10, i64 0}
!28 = distinct !{!28, !18, !19}
!29 = distinct !{!29, !18, !19}
