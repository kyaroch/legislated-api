describe Bill do
  describe "scopes" do
    describe "by_date" do
      let!(:date) { Time.now }
      let!(:bill2) { create(:bill, hearing: create(:hearing, :with_any_committee, date: date)) }
      let!(:bill1) { create(:bill, hearing: create(:hearing, :with_any_committee, date: date - 1.day)) }

      it "sorts the bills by ascending hearing date" do
        expect(Bill.by_date).to eq([bill1, bill2])
      end

      context "with a start_date" do
        it "only returns bills after that date" do
          expect(Bill.by_date(date)).to eq([bill2])
        end
      end
    end

    describe "ordered_by_date" do
      let!(:date) { Time.now }
      let!(:bill2) { create(:bill, hearing: create(:hearing, :with_any_committee, date: date)) }
      let!(:bill1) { create(:bill, hearing: create(:hearing, :with_any_committee, date: date - 1.day)) }

      it "sorts the bills by ascending hearing date" do
        expect(Bill.ordered_by_date).to eq([bill1, bill2])
      end
    end
  end
end