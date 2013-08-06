-include config.mk

DEBUG ?= 0

ifeq ($(strip $(DEBUG)),1)
        CXXFLAGS := -Ithird-party/lz4 -Wall -g -fno-omit-frame-pointer --std=c++0x
else
        CXXFLAGS := -Ithird-party/lz4 -Wall -Werror -O2 -funroll-loops -fno-omit-frame-pointer --std=c++0x
endif

TOP     := $(shell echo $${PWD-`pwd`})
LDFLAGS := -lpthread -lnuma -lrt

LZ4LDFLAGS := -Lthird-party/lz4 -llz4 -Wl,-rpath,$(TOP)/third-party/lz4

# 0 = libc malloc
# 1 = jemalloc
# 2 = tcmalloc
# 3 = flow
USE_MALLOC_MODE ?= 1

# 0 = disable perf counters
# 1 = enable perf counters
USE_PERF_CTRS ?= 0

ifeq ($(strip $(USE_MALLOC_MODE)),1)
        CXXFLAGS+=-DUSE_JEMALLOC
        LDFLAGS+=-ljemalloc
else
ifeq ($(strip $(USE_MALLOC_MODE)),2)
        CXXFLAGS+=-DUSE_TCMALLOC
        LDFLAGS+=-ltcmalloc
else
ifeq ($(strip $(USE_MALLOC_MODE)),3)
        CXXFLAGS+=-DUSE_FLOW
        LDFLAGS+=-lflow
endif
endif
endif

ifneq ($(strip $(CUSTOM_LDPATH)), )
        LDFLAGS+=$(CUSTOM_LDPATH)
endif

ifeq ($(USE_PERF_CTRS),1)
	CXXFLAGS+=-DUSE_PERF_CTRS
endif

HEADERS = allocator.h \
	amd64.h \
	base_txn_btree.h \
	btree.h \
	circbuf.h \
	core.h \
	counter.h \
	hash_bytes.h \
	imstring.h \
	keyrange.h \
	lockguard.h \
	macros.h \
	marked_ptr.h \
	ndb_type_traits.h \
	prefetch.h \
	rcu.h \
	record/cursor.h \
	record/encoder.h \
	record/inline_str.h \
	record/serializer.h \
	scopedperf.hh \
	small_unordered_map.h \
	small_vector.h \
	spinbarrier.h \
	spinlock.h \
	static_assert.h \
	static_unordered_map.h \
	static_vector.h \
	ticker.h \
	thread.h \
	tuple.h \
	txn_btree.h \
	txn.h \
	txn_impl.h \
	txn_proto1_impl.h \
	txn_proto2_impl.h \
	typed_txn_btree.h \
	util.h \
	varint.h \
	varkey.h \
	xbuf.h
SRCFILES = allocator.cc \
	btree.cc \
	core.cc \
	counter.cc \
	hash_bytes.cc \
	keyrange.cc \
	memory.cc \
	rcu.cc \
	thread.cc \
	ticker.cc \
	tuple.cc \
	txn_btree.cc \
	txn.cc \
	txn_proto1_impl.cc \
	txn_proto2_impl.cc \
	varint.cc

OBJFILES = $(SRCFILES:.cc=.o)

MYSQL_SHARE_DIR=/x/stephentu/mysql-5.5.29/build/sql/share

BENCH_CXXFLAGS := $(CXXFLAGS) -DMYSQL_SHARE_DIR=\"$(MYSQL_SHARE_DIR)\"
BENCH_LDFLAGS := $(LDFLAGS) -L/usr/lib/mysql -ldb_cxx -lmysqld -lz -lrt -lcrypt -laio -ldl -lssl -lcrypto

BENCH_HEADERS = $(HEADERS) \
	benchmarks/abstract_db.h \
	benchmarks/abstract_ordered_index.h \
	benchmarks/bdb_wrapper.h \
	benchmarks/bench.h \
	benchmarks/kvdb_wrapper.h \
	benchmarks/kvdb_wrapper_impl.h \
	benchmarks/masstree/kvrandom.hh \
	benchmarks/mysql_wrapper.h \
	benchmarks/ndb_wrapper.h \
	benchmarks/ndb_wrapper_impl.h \
	benchmarks/str_arena.h \
	benchmarks/tpcc.h
BENCH_SRCFILES = benchmarks/bdb_wrapper.cc \
	benchmarks/bench.cc \
	benchmarks/encstress.cc \
	benchmarks/masstree/kvrandom.cc \
	benchmarks/mysql_wrapper.cc \
	benchmarks/queue.cc \
	benchmarks/tpcc.cc \
	benchmarks/ycsb.cc
BENCH_OBJFILES = $(BENCH_SRCFILES:.cc=.o)

NEWBENCH_HEADERS = $(HEADERS) \
	new-benchmarks/abstract_db.h \
	new-benchmarks/abstract_ordered_index.h \
	new-benchmarks/bench.h \
	new-benchmarks/kvdb_database.h \
	new-benchmarks/ndb_database.h \
	new-benchmarks/str_arena.h \
	new-benchmarks/tpcc.h

NEWBENCH_SRCFILES = new-benchmarks/bench.cc \
	new-benchmarks/tpcc.cc
NEWBENCH_OBJFILES = $(NEWBENCH_SRCFILES:.cc=.o)

all: test

benchmarks/%.o: benchmarks/%.cc $(BENCH_HEADERS)
	$(CXX) $(BENCH_CXXFLAGS) -c $< -o $@

benchmarks/masstree/%.o: benchmarks/masstree/%.cc $(BENCH_HEADERS)
	$(CXX) $(BENCH_CXXFLAGS) -c $< -o $@

new-benchmarks/%.o: new-benchmarks/%.cc $(NEWBENCH_HEADERS)
	$(CXX) $(CXXFLAGS) -c $< -o $@

%.o: %.cc $(HEADERS)
	$(CXX) $(CXXFLAGS) -c $< -o $@

test: test.o $(OBJFILES) third-party/lz4/liblz4.so
	$(CXX) -o test $^ $(LDFLAGS) $(LZ4LDFLAGS)

third-party/lz4/liblz4.so:
	make -C third-party/lz4 library

persist_test: persist_test.o third-party/lz4/liblz4.so
	$(CXX) -o persist_test persist_test.o $(LDFLAGS) $(LZ4LDFLAGS)

.PHONY: dbtest
dbtest: benchmarks/dbtest

benchmarks/dbtest: benchmarks/dbtest.o $(OBJFILES) $(BENCH_OBJFILES) third-party/lz4/liblz4.so
	$(CXX) -o benchmarks/dbtest $^ $(BENCH_LDFLAGS) $(LZ4LDFLAGS)

.PHONY: kvtest
kvtest: benchmarks/masstree/kvtest

benchmarks/masstree/kvtest: benchmarks/masstree/kvtest.o $(OBJFILES) $(BENCH_OBJFILES)
	$(CXX) -o benchmarks/masstree/kvtest $^ $(BENCH_LDFLAGS)

.PHONY: newdbtest
newdbtest: new-benchmarks/dbtest

new-benchmarks/dbtest: new-benchmarks/dbtest.o $(OBJFILES) $(NEWBENCH_OBJFILES) third-party/lz4/liblz4.so
	$(CXX) -o new-benchmarks/dbtest $^ $(LDFLAGS) $(LZ4LDFLAGS)

.PHONY: clean
clean:
	rm -f *.o test persist_test benchmarks/*.o benchmarks/dbtest \
		benchmarks/masstree/*.o benchmarks/masstree/kvtest \
		new-benchmarks/*.o new-benchmarks/dbtest
	make -C third-party/lz4 clean
