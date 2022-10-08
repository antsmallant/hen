// modify from skynet/service-src/service_logger.c

#include "skynet.h"

#include <stdio.h>
#include <stdlib.h>
#include <stdint.h>
#include <string.h>
#include <time.h>

struct logger {
	FILE * handle;
	char * filename;
	uint32_t starttime;
	int close;

	time_t now;
	struct tm tm_now;
	char nowstr[32];
};

static const char*
_now(struct logger * inst) {
	time_t now = time(NULL);
	if (now == inst->now) {
		return inst->nowstr;
	}
	localtime_r(&now, &inst->tm_now);
	strftime(inst->nowstr, sizeof(inst->nowstr), "%F %T", &inst->tm_now);
	inst->now = now;
	return inst->nowstr;
}

struct logger *
henlogger_create(void) {
	struct logger * inst = skynet_malloc(sizeof(*inst));
	inst->handle = NULL;
	inst->close = 0;
	inst->filename = NULL;

	return inst;
}

void
henlogger_release(struct logger * inst) {
	if (inst->close) {
		fclose(inst->handle);
	}
	skynet_free(inst->filename);
	skynet_free(inst);
}

#define SIZETIMEFMT	250

static int
timestring(struct logger *inst, char tmp[SIZETIMEFMT]) {
	uint64_t now = skynet_now();
	time_t ti = now/100 + inst->starttime;
	struct tm info;
	(void)localtime_r(&ti,&info);
	strftime(tmp, SIZETIMEFMT, "%d/%m/%y %H:%M:%S", &info);
	return now % 100;
}

static int
henlogger_cb(struct skynet_context * context, void *ud, int type, int session, uint32_t source, const void * msg, size_t sz) {
	struct logger * inst = ud;
	switch (type) {
	case PTYPE_SYSTEM:
		if (inst->filename) {
			inst->handle = freopen(inst->filename, "a", inst->handle);
		}
		break;
	case PTYPE_TEXT:
        fprintf(inst->handle, "[%s :%08x] ", _now(inst), source);
		fwrite(msg, sz , 1, inst->handle);
		fprintf(inst->handle, "\n");
		fflush(inst->handle);
		break;
	}

	return 0;
}

int
henlogger_init(struct logger * inst, struct skynet_context *ctx, const char * parm) {
	const char * r = skynet_command(ctx, "STARTTIME", NULL);
	inst->starttime = strtoul(r, NULL, 10);
	if (parm) {
		inst->handle = fopen(parm,"a");
		if (inst->handle == NULL) {
			return 1;
		}
		inst->filename = skynet_malloc(strlen(parm)+1);
		strcpy(inst->filename, parm);
		inst->close = 1;
	} else {
		inst->handle = stdout;
	}
	if (inst->handle) {
		skynet_callback(ctx, inst, henlogger_cb);
		return 0;
	}
	return 1;
}
