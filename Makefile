.PHONY: all test clean cleanall mnist yolo2 yolo3 mobilenet2

RELEASE ?= 0
CC := gcc
override CFLAGS += -Iinclude -Wall -std=c99
ifeq ($(RELEASE), 1)
	override CFLAGS += -O3
else
	override CFLAGS += -O0 -g -fsanitize=address
endif

LIBS := -lprotobuf-c -lm -lpthread
OPSET_OBJS := $(patsubst src/%.c, obj/%.o, $(wildcard src/opset_*.c))
OBJS := $(patsubst src/%.c, obj/%.o, $(wildcard src/*.c)) obj/opset.o obj/onnx.proto3.pb-c.o

all: connx

mnist: all
	./connx examples/mnist/model.onnx -i examples/mnist/test_data_set_0/input_0.pb -t examples/mnist/test_data_set_0/output_0.pb -d -e 0.001 -l 1000

yolo2: all
	./connx examples/tiny_yolov2/Model.onnx -i examples/tiny_yolov2/test_data_set_0/input_0.pb -t examples/tiny_yolov2/test_data_set_0/output_0.pb -d -e 0.0001 -l 100

yolo3: all
	./connx examples/yolov3-tiny/yolov3-tiny.onnx -i examples/yolov3-tiny/test_data_set_0/input_0.pb -i examples/yolov3-tiny/test_data_set_0/input_1.pb -t examples/yolov3-tiny/test_data_set_0/output_0.pb -t examples/yolov3-tiny/test_data_set_0/output_1.pb -t examples/yolov3-tiny/test_data_set_0/output_2.pb -d -e 0.001 -l 100 -p N=1,_=416

mobilenet2: all
	./connx examples/mobilenet2/mobilenetv2-7.onnx -i examples/mobilenet2/test_data_set_0/input_0.pb -t examples/mobilenet2/test_data_set_0/output_0.pb -d -e 0.001 -l 1

clean:
	make -C test clean
	rm src/opset.c
	rm -rf obj
	rm -f connx

cleanall: clean
	rm src/onnx.proto3.pb-c.c
	rm include/onnx/onnx.proto3.pb-c.h
	rmdir include/onnx

test: all bin/re2c
	make -C test run

bin/re2c: bin/re2c-1.3.tar.gz
	rm -rf obj
	mkdir -p obj
	cd obj; tar fxz ../$^
	cd obj/$(notdir $(basename $(basename $^))); autoreconf -i -W all
	cd obj/$(notdir $(basename $(basename $^))); ./configure
	cd obj/$(notdir $(basename $(basename $^))); make
	cp obj/$(notdir $(basename $(basename $^)))/re2c bin/
	rm -rf obj

connx: $(OBJS)
	$(CC) $(CFLAGS) -o $@ $^ $(LIBS)


src/opset.c:
	bin/opset.sh $(OPSET_OBJS)

src/onnx.proto3.pb-c.c: onnx/onnx/onnx.proto3
	cd onnx; protoc-c onnx/onnx.proto3 --c_out ../src
	mv src/onnx/onnx.proto3.pb-c.c src/
	mv src/onnx include/

obj/%.d: src/%.c src/onnx.proto3.pb-c.c
	mkdir -p obj; $(CC) $(CFLAGS) -M $< > $@

-include $(patsubst src/%.c, obj/%.d, $(wildcard src/*.c))  

obj/%.o: src/%.c
	mkdir -p obj; $(CC) $(CFLAGS) -c -o $@ $^
