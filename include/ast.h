#ifndef DIRI_AST_H
#define DIRI_AST_H

#include <stddef.h>

typedef enum {
    DIRI_AST_PROGRAM = 0,
    DIRI_AST_STRUCT_DECL,
    DIRI_AST_FUNCTION,
    DIRI_AST_EXTERN_FUNCTION,
    DIRI_AST_LET_STMT,
    DIRI_AST_ASSIGN_STMT,
    DIRI_AST_FIELD_ASSIGN_STMT,
    DIRI_AST_INDEX_ASSIGN_STMT,
    DIRI_AST_RETURN_STMT,
    DIRI_AST_EXPR_STMT,
    DIRI_AST_IF_STMT,
    DIRI_AST_WHILE_STMT,
    DIRI_AST_INT_EXPR,
    DIRI_AST_BOOL_EXPR,
    DIRI_AST_STRING_EXPR,
    DIRI_AST_IDENT_EXPR,
    DIRI_AST_CALL_EXPR,
    DIRI_AST_BINARY_EXPR,
    DIRI_AST_FIELD_EXPR,
    DIRI_AST_STRUCT_INIT_EXPR,
    DIRI_AST_INDEX_EXPR,
    DIRI_AST_ARRAY_INIT_EXPR
} DiriAstKind;

typedef enum {
    DIRI_BIN_ADD = 0,
    DIRI_BIN_SUB,
    DIRI_BIN_MUL,
    DIRI_BIN_DIV,
    DIRI_BIN_EQ,
    DIRI_BIN_NE,
    DIRI_BIN_LT,
    DIRI_BIN_GT,
    DIRI_BIN_LE,
    DIRI_BIN_GE
} DiriBinaryOp;

typedef struct DiriAstType {
    const char *name;
} DiriAstType;

typedef struct DiriAstExpr DiriAstExpr;
typedef struct DiriAstStmt DiriAstStmt;
typedef struct DiriAstDecl DiriAstDecl;

typedef struct {
    const char *name;
    DiriAstType type;
} DiriAstField;

typedef struct {
    const char *name;
    DiriAstExpr *value;
} DiriAstInitField;

typedef struct {
    DiriAstExpr **items;
    size_t count;
} DiriAstExprList;

typedef struct {
    const char *name;
    DiriAstType type;
} DiriAstParam;

struct DiriAstExpr {
    DiriAstKind kind;
    const char *inferred_type;
    union {
        long int_value;
        int bool_value;
        const char *string_value;
        const char *ident_name;
        struct {
            const char *callee;
            DiriAstExpr **args;
            size_t arg_count;
        } call;
        struct {
            DiriBinaryOp op;
            DiriAstExpr *left;
            DiriAstExpr *right;
        } binary;
        struct {
            DiriAstExpr *base;
            const char *field_name;
        } field;
        struct {
            const char *type_name;
            DiriAstInitField *fields;
            size_t field_count;
        } struct_init;
        struct {
            DiriAstExpr *base;
            DiriAstExpr *index;
        } index;
        struct {
            DiriAstExpr **items;
            size_t item_count;
        } array_init;
    } as;
};

typedef struct {
    DiriAstStmt **items;
    size_t count;
} DiriAstBlock;

struct DiriAstStmt {
    DiriAstKind kind;
    union {
        struct {
            const char *name;
            DiriAstType type;
            DiriAstExpr *value;
        } let_stmt;
        struct {
            const char *name;
            DiriAstExpr *value;
        } assign_stmt;
        struct {
            DiriAstExpr *target;
            DiriAstExpr *value;
        } field_assign_stmt;
        struct {
            DiriAstExpr *target;
            DiriAstExpr *value;
        } index_assign_stmt;
        struct {
            DiriAstExpr *value;
        } return_stmt;
        struct {
            DiriAstExpr *expr;
        } expr_stmt;
        struct {
            DiriAstExpr *condition;
            DiriAstBlock then_block;
            DiriAstBlock else_block;
        } if_stmt;
        struct {
            DiriAstExpr *condition;
            DiriAstBlock body;
        } while_stmt;
    } as;
};

struct DiriAstDecl {
    DiriAstKind kind;
    const char *name;
    DiriAstParam *params;
    size_t param_count;
    DiriAstType return_type;
    DiriAstStmt **body;
    size_t body_count;
    DiriAstField *fields;
    size_t field_count;
};

typedef struct {
    DiriAstDecl **decls;
    size_t decl_count;
    int had_error;
} DiriAstProgram;

DiriAstProgram *diri_ast_program_new(void);
DiriAstDecl *diri_ast_decl_new(DiriAstKind kind, const char *name);
DiriAstStmt *diri_ast_stmt_new(DiriAstKind kind);
DiriAstExpr *diri_ast_expr_new(DiriAstKind kind);
char *diri_ast_strdup_range(const char *start, int length);
int diri_ast_program_add_decl(DiriAstProgram *program, DiriAstDecl *decl);
int diri_ast_decl_add_param(DiriAstDecl *decl, DiriAstParam param);
int diri_ast_decl_add_stmt(DiriAstDecl *decl, DiriAstStmt *stmt);
int diri_ast_decl_add_field(DiriAstDecl *decl, DiriAstField field);
int diri_ast_block_add_stmt(DiriAstBlock *block, DiriAstStmt *stmt);
int diri_ast_call_add_arg(DiriAstExpr *expr, DiriAstExpr *arg);
int diri_ast_struct_init_add_field(DiriAstExpr *expr, DiriAstInitField field);
int diri_ast_array_add_item(DiriAstExpr *expr, DiriAstExpr *item);
const char *diri_binary_op_name(DiriBinaryOp op);
void diri_ast_dump_program(const DiriAstProgram *program);
void diri_ast_program_free(DiriAstProgram *program);
const char *diri_ast_kind_name(DiriAstKind kind);

#endif
