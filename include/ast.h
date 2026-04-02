#ifndef DI_AST_H
#define DI_AST_H

#include <stddef.h>

typedef enum {
    DI_AST_PROGRAM = 0,
    DI_AST_STRUCT_DECL,
    DI_AST_FUNCTION,
    DI_AST_EXTERN_FUNCTION,
    DI_AST_VAR_STMT,
    DI_AST_ASSIGN_STMT,
    DI_AST_FIELD_ASSIGN_STMT,
    DI_AST_INDEX_ASSIGN_STMT,
    DI_AST_RETURN_STMT,
    DI_AST_EXPR_STMT,
    DI_AST_IF_STMT,
    DI_AST_WHILE_STMT,
    DI_AST_FLUX_STMT,
    DI_AST_INT_EXPR,
    DI_AST_BOOL_EXPR,
    DI_AST_STRING_EXPR,
    DI_AST_IDENT_EXPR,
    DI_AST_CALL_EXPR,
    DI_AST_BINARY_EXPR,
    DI_AST_UNARY_EXPR,
    DI_AST_FIELD_EXPR,
    DI_AST_STRUCT_INIT_EXPR,
    DI_AST_INDEX_EXPR,
    DI_AST_ARRAY_INIT_EXPR,
    DI_AST_RANGE_EXPR
} DiAstKind;

typedef enum {
    DI_BIN_ADD = 0,
    DI_BIN_SUB,
    DI_BIN_MUL,
    DI_BIN_DIV,
    DI_BIN_EQ,
    DI_BIN_NE,
    DI_BIN_LT,
    DI_BIN_GT,
    DI_BIN_LE,
    DI_BIN_GE,
    DI_BIN_AND,
    DI_BIN_OR
} DiBinaryOp;

typedef enum {
    DI_UNARY_NOT = 0
} DiUnaryOp;

typedef struct DiAstType {
    const char *name;
} DiAstType;

typedef struct DiAstExpr DiAstExpr;
typedef struct DiAstStmt DiAstStmt;
typedef struct DiAstDecl DiAstDecl;

typedef struct {
    const char *name;
    DiAstType type;
} DiAstField;

typedef struct {
    const char *name;
    DiAstExpr *value;
} DiAstInitField;

typedef struct {
    DiAstExpr **items;
    size_t count;
} DiAstExprList;

typedef struct {
    const char *name;
    DiAstType type;
} DiAstParam;

struct DiAstExpr {
    DiAstKind kind;
    const char *inferred_type;
    union {
        long int_value;
        int bool_value;
        const char *string_value;
        const char *ident_name;
        struct {
            DiAstExpr *callee;
            DiAstExpr **args;
            size_t arg_count;
            const char *resolved_name;
        } call;
        struct {
            DiBinaryOp op;
            DiAstExpr *left;
            DiAstExpr *right;
        } binary;
        struct {
            DiUnaryOp op;
            DiAstExpr *operand;
        } unary;
        struct {
            DiAstExpr *base;
            const char *field_name;
        } field;
        struct {
            const char *type_name;
            DiAstInitField *fields;
            size_t field_count;
        } struct_init;
        struct {
            DiAstExpr *base;
            DiAstExpr *index;
        } index;
        struct {
            DiAstExpr **items;
            size_t item_count;
        } array_init;
        struct {
            DiAstExpr *start;
            DiAstExpr *end;
        } range;
    } as;
};

typedef struct {
    DiAstStmt **items;
    size_t count;
} DiAstBlock;

struct DiAstStmt {
    DiAstKind kind;
    union {
        struct {
            const char *name;
            DiAstType type;
            DiAstExpr *value;
            int has_explicit_type;
        } var_stmt;
        struct {
            const char *name;
            DiAstExpr *value;
        } assign_stmt;
        struct {
            DiAstExpr *target;
            DiAstExpr *value;
        } field_assign_stmt;
        struct {
            DiAstExpr *target;
            DiAstExpr *value;
        } index_assign_stmt;
        struct {
            DiAstExpr *value;
        } return_stmt;
        struct {
            DiAstExpr *expr;
        } expr_stmt;
        struct {
            DiAstExpr *condition;
            DiAstBlock then_block;
            DiAstBlock else_block;
        } if_stmt;
        struct {
            DiAstExpr *condition;
            DiAstBlock body;
            DiAstStmt *update;
        } while_stmt;
        struct {
            const char *name;
            DiAstExpr *iterable;
            DiAstBlock body;
        } flux_stmt;
    } as;
};

struct DiAstDecl {
    DiAstKind kind;
    const char *name;
    const char *owner_type;
    DiAstParam *params;
    size_t param_count;
    DiAstType return_type;
    DiAstStmt **body;
    size_t body_count;
    DiAstField *fields;
    size_t field_count;
};

typedef struct {
    DiAstDecl **decls;
    size_t decl_count;
    int had_error;
} DiAstProgram;

DiAstProgram *di_ast_program_new(void);
DiAstDecl *di_ast_decl_new(DiAstKind kind, const char *name);
DiAstStmt *di_ast_stmt_new(DiAstKind kind);
DiAstExpr *di_ast_expr_new(DiAstKind kind);
char *di_ast_strdup_range(const char *start, int length);
int di_ast_program_add_decl(DiAstProgram *program, DiAstDecl *decl);
int di_ast_decl_add_param(DiAstDecl *decl, DiAstParam param);
int di_ast_decl_add_stmt(DiAstDecl *decl, DiAstStmt *stmt);
int di_ast_decl_add_field(DiAstDecl *decl, DiAstField field);
int di_ast_block_add_stmt(DiAstBlock *block, DiAstStmt *stmt);
int di_ast_call_add_arg(DiAstExpr *expr, DiAstExpr *arg);
int di_ast_struct_init_add_field(DiAstExpr *expr, DiAstInitField field);
int di_ast_array_add_item(DiAstExpr *expr, DiAstExpr *item);
const char *di_binary_op_name(DiBinaryOp op);
void di_ast_dump_program(const DiAstProgram *program);
void di_ast_program_free(DiAstProgram *program);
const char *di_ast_kind_name(DiAstKind kind);

#endif
