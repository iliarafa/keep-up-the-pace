import { type InputHTMLAttributes, forwardRef } from "react";
import { cn } from "@/lib/utils";

export const Input = forwardRef<HTMLInputElement, InputHTMLAttributes<HTMLInputElement>>(
  function Input({ className, type = "text", ...props }, ref) {
    return (
      <input
        ref={ref}
        type={type}
        className={cn(
          "flex h-14 w-full rounded-lg border border-line bg-surface px-4 text-base text-fg",
          "placeholder:text-faint",
          "transition-[border-color] duration-150 ease-out",
          "focus-visible:border-accent/60 focus-visible:outline-none",
          "disabled:opacity-50",
          className,
        )}
        {...props}
      />
    );
  },
);
