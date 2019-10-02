
require 'homebrew_automation/effects.rb'

describe 'HomebrewAutomation::Effects' do

  describe 'Eff' do
    let(:eff) { HomebrewAutomation::Effects::Eff }

    it 'can be aliased into an rspec let-binding' do
      expect(eff).not_to(be(nil))
      expect(eff.class).to(be(Class))
    end

    describe '::new' do

      it 'forms an identity with #run!' do
        expect(eff.new do 3 end.run!).to(be(3))
      end

    end

    describe '::pure' do

      it 'wraps a pure value into an Eff' do
        expect('abc').to(match(String))
        expect(eff.pure(3)).to(match(eff))
      end

      it 'forms an identity with #run!' do
        expect(eff.pure(3).run!).to(be(3))
      end

    end

    describe '#dup' do

      it 'returns a new and different Eff' do
        m = eff.pure 3
        o = m.dup
        expect(o).to(match(eff))
        expect(o).not_to(be(m))
      end

      it 'builds a new array, but keeps the old Procs' do
        m = eff.pure(3)
        o = m.dup
        marr = m.method(:steps).call
        oarr = o.method(:steps).call
        expect(o).not_to(be(m))
        expect(oarr).not_to(be(marr))
        expect(oarr).to(eq(marr))
        expect(oarr.length).to be 1
        expect(marr.length).to be 1
        mproc = marr.first
        oproc = oarr.first
        expect(mproc).to match(Proc)
        expect(oproc).to match(Proc)
        expect(mproc).to be(oproc)
      end

    end

    describe '#bind!' do

      let(:get_three) { eff.pure 3 }
      let(:monadic_incr) { Proc.new do |x| eff.pure(x + 1) end }

      it 'can bind the steps in sequence' do
        get_four = get_three.bind!(&monadic_incr)
        expect(get_four.run!).to be 4
      end

      it 'does not mutate the original Eff' do
        get_four = get_three.bind &monadic_incr
        expect(get_four).not_to be(get_three)
        expect(get_three.run!).to be 3
        expect(get_four.run!).to be 4
      end

      it 'mutates in-place if you use #bind!' do
        get_four = get_three.bind! &monadic_incr
        expect(get_four).to(be(get_three))
        expect(get_four.equal?(get_three)).to(be(true))
        expect(get_four.run!).to be 4
        expect(get_three.run!).to be 4  # mutated
      end

    end

    describe '#map and Functor behaviour' do

      let(:get_one) { eff.pure 1 }
      let(:pure_incr_lambda) { ->(x) { x + 1 } }
      let(:pure_incr_proc) { Proc.new do |x| x + 1 end }

      it 'can map over an Eff' do
        expect(eff.pure(3).map do |x| x + 1 end.run!).to(be(4))
      end

      it 'does not mutate the original Eff' do
        result_lambda = get_one.map(&pure_incr_lambda)
        result_proc = get_one.map(&pure_incr_proc)
        expect(result_lambda).not_to be(get_one)
        expect(result_proc).not_to be(get_one)
        expect(result_lambda.run!).to be 2
        expect(result_proc.run!).to be 2
        expect(get_one.run!).to be 1
      end

      it 'mutates in-place if you use #map!' do
        result_lambda = get_one.map!(&pure_incr_lambda)
        expect(result_lambda).to be(get_one)
        expect(result_lambda.run!).to be 2
        result_proc = get_one.map!(&pure_incr_proc)
        expect(result_proc).to be(get_one)
        expect(result_proc.run!).to be 3  # incremented again!
        expect(get_one.run!).to be 3
      end

    end

    describe '#apply and Applicative behaviour' do

      let(:get_three) { eff.pure(3) }
      let(:get_incr) { eff.pure(Proc.new do |x| x + 1 end) }

      it 'can apply a function returned by an Eff to the starting Eff' do
        expect(get_three.apply(get_incr).run!).to be 4
      end

      it 'does not mutate the original Eff' do
        get_four = get_three.apply(get_incr)
        expect(get_four).not_to be(get_three)
        expect(get_four.run!).to be 4
        expect(get_three.run!).to be 3
      end

      it 'mutates in-place if you use #apply!' do
        get_four = get_three.apply!(get_incr)
        expect(get_four).to be(get_three)
        expect(get_four.run!).to be 4
        expect(get_three.run!).to be 4    # mutated
      end

    end

    describe 'how to put things together to achieve imperative code' do

      # pretend these effects are not pure
      let(:one) { eff.pure 1 }
      let(:two) { eff.pure 2 }

      it 'be nested in callback-hell style' do
        main =
          one.bind! do |x|
          two.bind! do |y|
            eff.pure(x + y)
          end
          end
        expect(main.run!).to be 3
        expect(main).to be(one)   # remember it's mutations all the way
      end

      it 'allows abuse of #map! and #run! to approach do-syntax' do
        result =
          one.map! do |x|
            y = two.run!
            x + y
          end.run!
        expect(result).to be 3
      end

      it 'would lose its purpose if you called #run! everywhere' do
        result =
          eff.pure(42).map! do
            x = one.run!
            y = two.run!
            x + y
          end.run!
        expect(result).to be 3
      end

    end

  end

end