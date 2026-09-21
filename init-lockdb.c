#include <stdio.h>
#include <apr_general.h>
#include <apr_dbm.h>
#include <apr_errno.h>

int main(int argc, char **argv)
{
    apr_pool_t *pool = NULL;
    apr_dbm_t *db = NULL;
    apr_status_t status;
    char error[256];

    if (argc != 2) {
        fprintf(stderr, "Usage: %s LOCKDB_PATH\n", argv[0]);
        return 1;
    }

    status = apr_initialize();
    if (status != APR_SUCCESS) {
        fprintf(stderr, "Could not initialize APR: %s\n",
                apr_strerror(status, error, sizeof(error)));
        return 1;
    }

    status = apr_pool_create(&pool, NULL);
    if (status == APR_SUCCESS) {
        /* Match Davrods lock_local.c; RWCREATE preserves existing locks. */
        status = apr_dbm_open(&db, argv[1], APR_DBM_RWCREATE,
                              APR_OS_DEFAULT, pool);
    }
    if (status != APR_SUCCESS) {
        fprintf(stderr, "Could not initialize lock database %s: %s (%d)\n",
                argv[1], apr_strerror(status, error, sizeof(error)), status);
    }
    if (db != NULL)
        apr_dbm_close(db);
    if (pool != NULL)
        apr_pool_destroy(pool);
    apr_terminate();
    return status == APR_SUCCESS ? 0 : 1;
}
