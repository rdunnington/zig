const std = @import("std");

pub const requires_stage2 = true;

pub fn build(b: *std.Build) void {
    // Wasm Object file which we will use to infer the features from
    const c_obj = b.addObject(.{
        .name = "c_obj",
        .root_module = b.createModule(.{
            .root_source_file = null,
            .optimize = .Debug,
            .target = b.resolveTargetQuery(.{
                .cpu_arch = .wasm32,
                .cpu_model = .{ .explicit = &std.Target.wasm.cpu.bleeding_edge },
                .os_tag = .freestanding,
            }),
        }),
    });
    c_obj.root_module.addCSourceFile(.{ .file = b.path("foo.c"), .flags = &.{} });

    // Wasm library that doesn't have any features specified. This will
    // infer its featureset from other linked object files.
    const lib = b.addExecutable(.{
        .name = "lib",
        .root_module = b.createModule(.{
            .root_source_file = b.path("main.zig"),
            .optimize = .Debug,
            .target = b.resolveTargetQuery(.{
                .cpu_arch = .wasm32,
                .cpu_model = .{ .explicit = &std.Target.wasm.cpu.mvp },
                .os_tag = .freestanding,
            }),
        }),
    });
    lib.entry = .disabled;
    lib.use_llvm = false;
    lib.use_lld = false;
    lib.root_module.addObject(c_obj);

    // Verify the result contains the features from the C Object file.
    const check = lib.checkObject();
    check.checkInHeaders();
    check.checkExact("name target_features");
    check.checkExact("features 14");
    check.checkExact("+ atomics");
    check.checkExact("+ bulk-memory");
    check.checkExact("+ exception-handling");
    check.checkExact("+ extended-const");
    check.checkExact("+ half-precision");
    check.checkExact("+ multimemory");
    check.checkExact("+ multivalue");
    check.checkExact("+ mutable-globals");
    check.checkExact("+ nontrapping-fptoint");
    check.checkExact("+ reference-types");
    check.checkExact("+ relaxed-simd");
    check.checkExact("+ sign-ext");
    check.checkExact("+ simd128");
    check.checkExact("+ tail-call");

    const test_step = b.step("test", "Run linker test");
    test_step.dependOn(&check.step);
    b.default_step = test_step;
}
